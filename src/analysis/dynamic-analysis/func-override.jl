include("../../utils/lib.jl")
include("overrideinfo.jl")
include("ast-parse-helpers.jl")
include("overrideinfo-to-json.jl")

##################################
# Initialization of global vars
##################################

# Location of julia packages
PACKAGE_DIR = joinpath(DEPOT_PATH[1], "packages")
# Location of package being analyzed
DYNAMIC_ANALYSIS_PACKAGE_DIR = joinpath(PACKAGE_DIR, ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])
# Location of directory where output-data/environment will be stored
OUTPUT_DIR = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])"
# Make the directory if it does not exist
try mkdir(OUTPUT_DIR) catch e end

# Determines if the given stack frame occurs in the given directory
frameInDirectory(dir, frame) = findfirst(dir, string(frame.file)) != nothing
# Determines if given stack frame is from package source code
isSourceCode(stackFrame) = frameInDirectory(DYNAMIC_ANALYSIS_PACKAGE_DIR, stackFrame)
# Determines if given stack frame is from external library code
isExternalLibCode(stackFrame) = !isSourceCode(stackFrame) && frameInDirectory(PACKAGE_DIR, stackFrame)
# Determines if given stack frame is from internal julia library code
isInternalLibCode(stackFrame) = !(isSourceCode(stackFrame) || isExternalLibCode(stackFrame))
# Initialize empty dataCollection
overrideCollection = [
    OverrideInfo("source", isSourceCode),
    OverrideInfo("internal-lib", isInternalLibCode),
    OverrideInfo("external-lib", isExternalLibCode)
]

########################
# Overriden Functions
########################

# Overrides eval to store metadata about calls to the function
function Core.eval(m::Module, @nospecialize(e))
    exprs = extractExprs(e)
    for expr = exprs
        updateEvalInfoWrap(evalInfo :: EvalInfo) = updateEvalInfo(evalInfo, e, m)
        updateTraceAuxillary(astHeads :: AstInfo) = updateAstInfo(astHeads, e)
        updateFuncMetadata(overrideCollection, ((overrideInfo) -> overrideInfo.evalInfo), 3,
            updateEvalInfoWrap; auxTuple=((() -> Dict{Symbol,Count}()), updateTraceAuxillary))
    end

    # Original eval code
    ccall(:jl_toplevel_eval_in, Any, (Any, Any), m, e)
end

# Overrides invokelatest to store metadata about calls to the function
function Base.invokelatest(@nospecialize(f), @nospecialize args...; kwargs...)
    updateInvokeLatestInfo(invokeLatestInfo :: InvokeLatestInfo) = updateDictCount(invokeLatestInfo.funcNames, string(f))
    updateTraceAuxillary(funcNames :: FunctionInfo) = updateDictCount(funcNames, string(f))
    updateFuncMetadata(overrideCollection, ((overrideInfo) -> overrideInfo.invokeLatestInfo), 4,
        updateInvokeLatestInfo; auxTuple=((() -> Dict{String,Count}()), updateTraceAuxillary))

    # Original invokelatest code
    if isempty(kwargs)
        return Core._apply_latest(f, args)
    end
    # We use a closure (`inner`) to handle kwargs.
    inner() = f(args...; kwargs...)
    Core._apply_latest(inner)
end

##############################
# Function Override Helpers
##############################

# Adds one to the value of the key, creates keys with value of 1 if it does not already exist
updateDictCount(dict :: Dict{T, Count}, key :: T) where {T} = dict[key] = get!(dict, key, 0) + 1

# Updates the information for a new call to a function being analyzed
function updateFuncMetadata(overrideCollection :: Vector{OverrideInfo}, getFuncMetadata :: Function,
        stackFrameIndex :: Count, updateFuncSpecificData :: Function;
        auxTuple=((() -> nothing), ((aux) -> nothing)) :: Tuple{Function, Function})
    for overrideInfo = overrideCollection
        metadata = getFuncMetadata(overrideInfo)
        if overrideInfo.stackFramePredicate(getindex(stacktrace(), stackFrameIndex + 1))
            (defaultTraceAuxillary, updateTraceAuxillary) = auxTuple
            updateStackTraces(metadata.stackTraces, stackFrameIndex + 1, defaultTraceAuxillary, updateTraceAuxillary)
            metadata.callCount += 1
            updateFuncSpecificData(metadata.funcSpecificData)
        end
        storeOverrideInfo(overrideInfo, "$(OUTPUT_DIR)/$(overrideInfo.identifier).json")
    end
end

# Updates the metadata information for a stack trace
function updateStackTraces(stackTraces :: Dict{StackTraces.StackFrame, StackTraceInfo{U}},
        stackFrameIndex :: Count, defaultTraceAuxillary :: Function, updateTraceAuxillary :: Function
    ) where {U}
    stackFrame = getindex(stacktrace(), stackFrameIndex + 1)
    defaultStackTraceInfo = StackTraceInfo(defaultTraceAuxillary())
    stackTraceInfo = get!(stackTraces, stackFrame, defaultStackTraceInfo)
    stackTraceInfo.count += 1
    updateTraceAuxillary(stackTraceInfo.auxillary)
end

# Updates the ast information to increment the ast type of the given expression
function updateEvalInfo(evalInfo :: EvalInfo, e, m :: Module)
    astIdentifier = updateAstInfo(evalInfo.astHeads, e)
    if astIdentifier == :function
        if isLambdaFunc(e) # a lambda function (()->1)
            evalInfo.funcDefTypes.newFuncCount += 1
        elseif isLambdaBinding(e) # a variable bound to a lambda function (f=()->1)
            updateMiscCount(evalInfo, e, "Lambda binding used")
        elseif isAstWithBody(e, :function) && isa(e.args[1], Symbol) # function without body (function f end)
            evalInfo.funcDefTypes.bodylessFuncCount += 1
        else # a normal or abreviated definitio ((function f() 1 end) or (f()=1))
            try
                Core.isdefined(getFuncNameAndModule(e, m)...) ?
                    evalInfo.funcDefTypes.funcRedefCount += 1 :
                    evalInfo.funcDefTypes.newFuncCount += 1
            catch err
                updateMiscCount(evalInfo, e, "Issue with functin definition parse: (err: $(string(err)))")
            end
        end
    end
end

# Updates the ast information to increment the ast type of the given expression
function updateAstInfoHelp(astHeads :: AstInfo, astIdentifier :: Symbol)
    updateDictCount(astHeads, astIdentifier)
    astIdentifier
end
updateAstInfo(astHeads :: AstInfo, e :: Expr) = updateAstInfoHelp(astHeads, isIrregularFunction(e) ? :function : e.head)
updateAstInfo(astHeads :: AstInfo, e :: Symbol) = updateAstInfoHelp(astHeads, Symbol(string("Symbol-", e)))
updateAstInfo(astHeads :: AstInfo, e) = updateAstInfoHelp(astHeads, String(typeof(e)))

# Updates misc count and prints expression that is misc function definition
function updateMiscCount(evalInfo, e, msg)
    @info msg
    dump(e)
    evalInfo.funcDefTypes.miscCount += 1
end

# Extracts all expressions from a block, returns the expression if not a block
function extractExprs(e)
    if isAstWithBody(e, :block)
        foldr(((expr, exprs) -> vcat(extractExprs(expr), exprs)),
            filter(e -> !isa(e, LineNumberNode), e.args); init=[])
    else [e] end
end
