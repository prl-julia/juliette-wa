include("../../jl-transpiler/auxiliary/utils.jl")

#######################################
# Function Override Data Structures
#######################################

# Represents a counter
Count = Int64

# Represents an ast head distribution
AstInfo = Dict{Symbol, Count}

# Represents the a function name distribution
FunctionInfo = Dict{String, Count}

# Represents the distribution of function definition types
mutable struct FuncDefTracker
    newFuncCount :: Count
    funcRedefCount :: Count
    miscCount :: Count
    bodylessFuncCount :: Count
end
# Initializes a base representation of function type tracker
FuncDefTracker() = FuncDefTracker(0,0,0,0)

# Represents the information collected regarding eval function calls
mutable struct EvalInfo
    astHeads :: AstInfo
    funcDefTypes :: FuncDefTracker
end

# Represents the information collected regarding eval function calls
mutable struct InvokeLatestInfo
    funcNames :: FunctionInfo
end

# Represents the information collected regarding the stacktrace of a function call
mutable struct StackTraceInfo{T}
    count :: Count
    auxillary  :: T
end
# Initializes a base representation of stacktrace information
StackTraceInfo(funcSpecificData) = StackTraceInfo(0, funcSpecificData)

# Represents the information collected regarding overriden function calls
mutable struct FuncMetadata{T, U}
    callCount :: Count
    stackTraces :: Dict{StackTraces.StackFrame, StackTraceInfo{U}}
    funcSpecificData :: T
end
# Initializes a base representation of function metadata
FuncMetadata(funcSpecificData;
        initialTrace=Dict{StackTraces.StackFrame, StackTraceInfo{Nothing}}()
    ) = FuncMetadata(0, initialTrace, funcSpecificData)

# Represents the information being analyzed when running packages
mutable struct OverrideInfo
    identifier :: String
    stackFramePredicate :: Function
    evalInfo :: FuncMetadata{EvalInfo}
    invokeLatestInfo :: FuncMetadata{InvokeLatestInfo}
end
# Initializes a base representation of override information
OverrideInfo(identifier :: String, functionDataFilter :: Function) =
    OverrideInfo(identifier, functionDataFilter,
        FuncMetadata(EvalInfo(Dict(), FuncDefTracker());
            initialTrace=Dict{StackTraces.StackFrame,StackTraceInfo{AstInfo}}()),
        FuncMetadata(InvokeLatestInfo(Dict());
            initialTrace=Dict{StackTraces.StackFrame,StackTraceInfo{FunctionInfo}}())
    )

#######################
# Function Override
#######################

# All file names in the base julia language source code
INTERNAL_LIB_FILES = readlines("$(ENV["DYNAMIC_ANALYSIS_DIR"])/internal-lib-filenames.txt")
# All keywords associated with the base julia language source code
INTERNAL_LIB_KW = ["GenericIOBuffer", "__init__()"]
# All file names in the base julia language source code
SOURCE_FILES = readlines("$(ENV["DYNAMIC_ANALYSIS_DIR"])/source-filenames.txt")
# All keywords associated with the base julia language source code
SOURCE_KW = []

# Determines if given stack frame is from the given code base
function isInCode(stackFrame, codeFilenames, codeKw)
    frameInFile = (filename) -> occursin(filename, string(stackFrame.file))
    frameHasKw = (keyword) -> occursin(keyword, string(stackFrame.linfo))
    ormap(frameInFile, codeFilenames) || ormap(frameHasKw, codeKw)
end

# Determines if given stack frame is from package source code
isSourceCode(stackFrame) = isInCode(stackFrame, SOURCE_FILES, SOURCE_KW)
# Determines if given stack frame is from internal julia library code
isInternalLibCode(stackFrame) = !isSourceCode(stackFrame) && isInCode(stackFrame, INTERNAL_LIB_FILES, INTERNAL_LIB_KW)
# Determines if given stack frame is from external library code
isExternalLibCode(stackFrame) = !(isSourceCode(stackFrame) || isInternalLibCode(stackFrame))

# Initialize empty dataCollection
overrideCollection = [
    OverrideInfo("source", isSourceCode),
    OverrideInfo("internal-lib", isInternalLibCode),
    OverrideInfo("external-lib", isExternalLibCode)
]

# Adds one to the value of the key, creates keys with value of 1 if it does not already exist
updateDictCount(dict :: Dict{T, Count}, key :: T) where {T} = dict[key] = get!(dict, key, 0) + 1

# Determines if the given expression has the given ast head and a body of at least 1 subexpression
isAstWithBody(e :: Expr, head :: Symbol) = e.head == head && size(e.args)[1] > 0
isAstWithBody(e, head :: Symbol) = false

# Determines if the given expression is an abreviated function definition
isAbreviatedFunc(e :: Expr) =
    isAstWithBody(e, :(=)) &&
        (isAstWithBody(e.args[1], :call) ||
            (isAstWithBody(e.args[1], :(::)) &&
                isAstWithBody(e.args[1].args[1], :call)))
# Determines if the given expression is an abreviated function definition
isLambdaBinding(e :: Expr) =
    isAstWithBody(e, :(=)) &&
        (size(e.args)[1] > 1 &&
            isAstWithBody(e.args[2], :(->)))
# Determines if the given expression is an lambda function
isLambdaFunc(e) = isAstWithBody(e, :(->))
# Determines if the given expression is a irregularly defined function
isIrregularFunction(e) = isAbreviatedFunc(e) || isLambdaBinding(e) || isLambdaFunc(e)

# Updates the ast information to increment the ast type of the given expression
function updateAstInfo(astHeads :: AstInfo, astIdentifier :: Symbol)
    updateDictCount(astHeads, astIdentifier)
    astIdentifier
end
updateAstInfo(astHeads :: AstInfo, e :: Expr) = updateAstInfo(astHeads, isIrregularFunction(e) ? :function : e.head)
updateAstInfo(astHeads :: AstInfo, e) = updateAstInfo(astHeads, Symbol(typeof(e)))

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
        if isLambdaFunc(e)
            evalInfo.funcDefTypes.newFuncCount += 1
        elseif isLambdaBinding(e)
            dump(e)
            evalInfo.funcDefTypes.miscCount += 1
        elseif isAstWithBody(e, :function) && isa(e.args[1], Symbol)
            evalInfo.funcDefTypes.bodylessFuncCount += 1
        else
            try
                Core.isdefined(getFuncNameAndModule(e, m)...) ?
                    evalInfo.funcDefTypes.funcRedefCount += 1 :
                    evalInfo.funcDefTypes.newFuncCount += 1
            catch err
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

# Overrides eval to store metadata about calls to the function
function Core.eval(m::Module, @nospecialize(e))
    updateEvalInfoWrap(evalInfo :: EvalInfo) = updateEvalInfo(evalInfo, e, m)
    updateTraceAuxillary(astHeads :: AstInfo) = updateAstInfo(astHeads, e)
    frameToGet = 3
    for overrideInfo = overrideCollection
        updateFuncMetadata(overrideInfo.evalInfo, frameToGet,
            updateEvalInfoWrap; stackFramePredicate=overrideInfo.stackFramePredicate,
            auxTuple=((() -> Dict{Symbol,Count}()), updateTraceAuxillary))
        storeOverrideInfo(overrideInfo)
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
        storeOverrideInfo(overrideInfo)
    end


    # Original invokelatest code
    if isempty(kwargs)
        return Core._apply_latest(f, args)
    end
    # We use a closure (`inner`) to handle kwargs.
    inner() = f(args...; kwargs...)
    Core._apply_latest(inner)
end

##############################
# OverrideInfo to JSON file
##############################

using Pkg
Pkg.add("JSON")
using JSON

# Store the overrideInfo as a JSON file
function storeOverrideInfo(overrideInfo :: OverrideInfo) :: Nothing
    try
        mkdir("$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])")
    catch e end
    OUTPUT_FILE = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])/$(overrideInfo.identifier).json"
    fd = open(OUTPUT_FILE, "w+")
    INDENT_SIZE = 2
    JSON.print(fd, overrideInfoToJson(overrideInfo), INDENT_SIZE)
    close(fd)
end

# Convert an OverrideInfo object to a julia json representation
function overrideInfoToJson(info :: OverrideInfo)
    json = Dict()
    json["eval_info"] = funcMetadataToJson(info.evalInfo,
        evalInfoToJson;
        traceAuxillaryToJson=astInfoToJson)
    json["invokelatest_info"] = funcMetadataToJson(info.invokeLatestInfo,
        (invokeLatestInfo) -> Dict(["function_names" => countingDictToJson(invokeLatestInfo.funcNames, "function_name")]);
        traceAuxillaryToJson=funcInfoToJson)
    json
end

# Convert an evalInfo object to a julia json representation
function evalInfoToJson(evalInfo :: EvalInfo)
    json = astInfoToJson(evalInfo.astHeads)
    json["func_def_types"] = funcDefTrackerToJson(evalInfo.funcDefTypes)
    json
end

# Convert an functionInfo object to a julia json representation
funcInfoToJson(funcNames :: FunctionInfo) = Dict(["function_names" => countingDictToJson(funcNames, "function_name")])

# Convert an astInfo object to a julia json representation
astInfoToJson(astHeads :: AstInfo) = Dict{Any, Any}(["ast_heads" => countingDictToJson(astHeads, "ast_head")])

# Convert an functionDefTracker object to a julia json representation
function funcDefTrackerToJson(funcDefTypes :: FuncDefTracker)
    json = Dict()
    json["newFuncCount"] = funcDefTypes.newFuncCount
    json["funcRedefCount"] = funcDefTypes.funcRedefCount
    json["miscCount"] = funcDefTypes.miscCount
    json["bodylessFuncCount"] = funcDefTypes.bodylessFuncCount
    json
end

# Convert an FuncMetadata object to a julia json representation
function funcMetadataToJson(funcMetadata :: FuncMetadata,
        funcSpecificDataToJson :: Function; traceAuxillaryToJson=((aux) -> Dict()) :: Function)
    json = Dict()
    json["call_count"] = funcMetadata.callCount
    json["stack_traces"] = stackTracesToJson(funcMetadata.stackTraces, traceAuxillaryToJson)
    json["func_specific_data"] = funcSpecificDataToJson(funcMetadata.funcSpecificData)
    json
end

# Convert a dictionary of stack traces to its respective julia json representation
function stackTracesToJson(stackTraces :: Dict{StackTraces.StackFrame, StackTraceInfo{U}},
        traceAuxillaryToJson :: Function
    ) where {U}
    sortedDict = sort!(collect(stackTraces), by = pair -> pair.second.count, rev = true)
    function traceToJson((key, traceInfo), acc)
        append!([Dict([
            "count" => traceInfo.count,
            "auxillary" => traceAuxillaryToJson(traceInfo.auxillary),
            "last_call" => string(key)
            ])], acc)
    end
    foldr(traceToJson, sortedDict; init = [])
end

# Convert a dictionary counting instance occurances to a sorted julia json representation
function countingDictToJson(dict :: Dict{T, Count}, keyName :: String) where {T}
    sortedDict = sort!(collect(dict), by = pair -> pair.second, rev = true)
    function dictToJson((key, count), acc)
        append!([Dict(["count" => count, keyName => string(key)])], acc)
    end
    foldr(dictToJson, sortedDict; init = [])
end
