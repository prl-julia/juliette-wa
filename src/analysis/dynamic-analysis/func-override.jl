include("../../utils/lib.jl")
include("overrideinfo.jl")
include("overrideinfo-to-json.jl")

#######################
# Function Override
#######################

# Location of julia packages
PACKAGE_DIR = joinpath(DEPOT_PATH[1], "packages")
# Location of dynamic analysis package
DYNAMIC_ANALYSIS_PACKAGE_DIR = joinpath(PACKAGE_DIR, ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])

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

OUTPUT_DIR = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])"

# Adds one to the value of the key, creates keys with value of 1 if it does not already exist
updateDictCount(dict :: Dict{T, Count}, key :: T) where {T} = dict[key] = get!(dict, key, 0) + 1

# Determines if the given expression has the given ast head and a body of at least 1 subexpression
isAstWithBody(e :: Expr, head :: Symbol) = e.head == head && size(e.args)[1] > 0
isAstWithBody(e, head :: Symbol) = false

# Determines if the given expression is an abreviated function definition
# eg: f() = 1
isAbreviatedFunc(e :: Expr) =
    isAstWithBody(e, :(=)) &&
        (isAstWithBody(e.args[1], :call) ||
            (isAstWithBody(e.args[1], :(::)) &&
                isAstWithBody(e.args[1].args[1], :call)))
# Determines if the given expression is an abreviated function definition
# eg: f = () -> 1
isLambdaBinding(e :: Expr) =
    isAstWithBody(e, :(=)) &&
        (size(e.args)[1] > 1 &&
            isAstWithBody(e.args[2], :(->)))
# Determines if the given expression is an lambda function
# eg: () -> 1
isLambdaFunc(e) = isAstWithBody(e, :(->))
# Determines if the given expression is a irregularly defined function
isIrregularFunction(e) = isAbreviatedFunc(e) || isLambdaBinding(e) || isLambdaFunc(e)

# Updates the ast information to increment the ast type of the given expression
function updateAstInfoHelp(astHeads :: AstInfo, astIdentifier :: Symbol)
    updateDictCount(astHeads, astIdentifier)
    astIdentifier
end
updateAstInfo(astHeads :: AstInfo, e :: Expr) = updateAstInfoHelp(astHeads, isIrregularFunction(e) ? :function : e.head)
updateAstInfo(astHeads :: AstInfo, e :: Symbol) = updateAstInfoHelp(astHeads, Symbol(string("Symbol-", e)))
updateAstInfo(astHeads :: AstInfo, e) = updateAstInfoHelp(astHeads, String(typeof(e)))

function getFuncNameAndModule(e :: Expr, m :: Module)
    maybeCallExpr = e.args[1]
    if isAstWithBody(maybeCallExpr, :call)
        funcDef = maybeCallExpr.args[1]
        if isa(funcDef, Symbol)
            return (m, funcDef)
        elseif isAstWithBody(funcDef, :(.)) &&
                isa(funcDef.args[2], QuoteNode) &&
                isa(funcDef.args[1], Module)
            return (funcDef.args[1], funcDef.args[2].value)
        elseif isAstWithBody(funcDef, :(.)) &&
                isa(funcDef.args[2], QuoteNode) &&
                isa(funcDef.args[1], Symbol)
            return (eval(funcDef.args[1]), funcDef.args[2].value)
        end
    elseif isa(e, Expr) && (size(e.args)[1] > 0)
        return getFuncNameAndModule(maybeCallExpr, m)
    end
    throw(DomainError(e))
end

# Updates the ast information to increment the ast type of the given expression
function updateEvalInfo(evalInfo :: EvalInfo, e, m :: Module)
    astIdentifier = updateAstInfo(evalInfo.astHeads, e)
    if astIdentifier == :function
        # a lambda function (()->1)
        if isLambdaFunc(e)
            evalInfo.funcDefTypes.newFuncCount += 1
        # a variable bound to a lambda function (f=()->1)
        elseif isLambdaBinding(e)
            @info "Dumping the AST of an expression classified as a lambda binding"
            dump(e)
            evalInfo.funcDefTypes.miscCount += 1
        # function without body (function f end)
        elseif isAstWithBody(e, :function) && isa(e.args[1], Symbol)
            evalInfo.funcDefTypes.bodylessFuncCount += 1
        else
            try
                Core.isdefined(getFuncNameAndModule(e, m)...) ?
                    evalInfo.funcDefTypes.funcRedefCount += 1 :
                    evalInfo.funcDefTypes.newFuncCount += 1
            catch err
                @info "Dumping the AST of an expression classified as func but unknown structure"
                println(err)
                dump(e)
                evalInfo.funcDefTypes.miscCount += 1
            end
        end
    end
end

# Updates the information for a stack trace
function updateStackTraces(stackTraces :: Dict{StackTraces.StackFrame, StackTraceInfo{U}},
        stackFrameIndex :: Count, defaultTraceAuxillary :: Function, updateTraceAuxillary :: Function
    ) where {U}
    stackFrame = getindex(stacktrace(), stackFrameIndex + 1)
    defaultStackTraceInfo = StackTraceInfo(defaultTraceAuxillary())
    stackTraceInfo = get!(stackTraces, stackFrame, defaultStackTraceInfo)
    stackTraceInfo.count += 1
    updateTraceAuxillary(stackTraceInfo.auxillary)
end

# Updates the information for a new call to a function being analyzed
function updateFuncMetadata(metadata :: FuncMetadata, stackFrameIndex :: Count, updateFuncSpecificData :: Function;
        stackFramePredicate=((frame) -> true) :: Function,
        auxTuple=((() -> nothing), ((aux) -> nothing)) :: Tuple{Function, Function})
    if stackFramePredicate(getindex(stacktrace(), stackFrameIndex + 1))
        (defaultTraceAuxillary, updateTraceAuxillary) = auxTuple
        # Update stack traces
        updateStackTraces(metadata.stackTraces, stackFrameIndex + 1, defaultTraceAuxillary, updateTraceAuxillary)
        # Update call counter
        metadata.callCount += 1
        # Update function specific data
        updateFuncSpecificData(metadata.funcSpecificData)
    end
end

function extractExprs(e)
    if isAstWithBody(e, :block)
        foldr(((expr, exprs) -> vcat(extractExprs(expr), exprs)),
            filter(e -> !isa(e, LineNumberNode), e.args); init=[])
    else
        [e]
    end
end

function updateEvalOverrideInfo(e, m)
    updateEvalInfoWrap(evalInfo :: EvalInfo) = updateEvalInfo(evalInfo, e, m)
    updateTraceAuxillary(astHeads :: AstInfo) = updateAstInfo(astHeads, e)
    frameToGet = 4
    for overrideInfo = overrideCollection
        updateFuncMetadata(overrideInfo.evalInfo, frameToGet,
            updateEvalInfoWrap; stackFramePredicate=overrideInfo.stackFramePredicate,
            auxTuple=((() -> Dict{Symbol,Count}()), updateTraceAuxillary))
        storeOverrideInfo(overrideInfo, OUTPUT_DIR, "$(overrideInfo.identifier).json")
    end
end

# Overrides eval to store metadata about calls to the function
function Core.eval(m::Module, @nospecialize(e))
    exprs = extractExprs(e)
    for expr = exprs
        updateEvalOverrideInfo(expr, m)
    end

    # Original eval code
    ccall(:jl_toplevel_eval_in, Any, (Any, Any), m, e)
end

# Overrides invokelatest to store metadata about calls to the function
function Base.invokelatest(@nospecialize(f), @nospecialize args...; kwargs...)
    updateInvokeLatestInfo(invokeLatestInfo :: InvokeLatestInfo) = updateDictCount(invokeLatestInfo.funcNames, string(f))
    updateTraceAuxillary(funcNames :: FunctionInfo) = updateDictCount(funcNames, string(f))
    frameToGet = 4
    for overrideInfo = overrideCollection
        updateFuncMetadata(overrideInfo.invokeLatestInfo, frameToGet,
            updateInvokeLatestInfo; stackFramePredicate=overrideInfo.stackFramePredicate,
            auxTuple=((() -> Dict{String,Count}()), updateTraceAuxillary))
        storeOverrideInfo(overrideInfo, OUTPUT_DIR, "$(overrideInfo.identifier).json")
    end

    # Original invokelatest code
    if isempty(kwargs)
        return Core._apply_latest(f, args)
    end
    # We use a closure (`inner`) to handle kwargs.
    inner() = f(args...; kwargs...)
    Core._apply_latest(inner)
end
