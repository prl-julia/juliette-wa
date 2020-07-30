#######################################
# Function Override Data Structures
#######################################

# Represents a counter
Count = Int64

# Represents an ast head distribution
AstInfo = Dict{Symbol, Count}

# Represents the a function name distribution
FunctionInfo = Dict{String, Count}

# Represents the information collected regarding eval function calls
mutable struct EvalInfo
    astHeads :: AstInfo
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
    evalInfo :: FuncMetadata{EvalInfo}
    invokeLatestInfo :: FuncMetadata{InvokeLatestInfo}
end

# Initialize empty overrideInfo
overrideInfo = OverrideInfo(FuncMetadata(EvalInfo(Dict());
                                initialTrace=Dict{StackTraces.StackFrame,StackTraceInfo{AstInfo}}()),
                            FuncMetadata(InvokeLatestInfo(Dict());
                                initialTrace=Dict{StackTraces.StackFrame,StackTraceInfo{FunctionInfo}}()))

#######################
# Function Override
#######################

# Adds one to the value of the key, creates keys with value of 1 if it does not already exist
updateDictCount(dict :: Dict{T, Count}, key :: T) where {T} = dict[key] = get!(dict, key, 0) + 1

# Determines if the given expression has the given ast head and a body of at least 1 subexpression
isAstWithBody(e :: Expr, head :: Symbol) = e.head == head && size(e.args)[1] > 0
isAstWithBody(e, head :: Symbol) = false

# Determines if the given expression is an abreviated function
isAbreviatedFunc(e :: Expr) = isAstWithBody(e, :(=)) &&
                                (isAstWithBody(e.args[1], :call) ||
                                (isAstWithBody(e.args[1], :(::)) &&
                                    isAstWithBody(e.args[1].args[1], :call)))

# Updates the ast information to increment the ast type of the given expression
function updateAstInfo(astHeads :: AstInfo, e :: Expr)
    astIdentifier = isAbreviatedFunc(e) ? :function : e.head
    updateDictCount(astHeads, astIdentifier)
end
updateAstInfo(astHeads :: AstInfo, e) = updateDictCount(astHeads, Symbol(typeof(e)))

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
        auxTuple=((() -> nothing), ((aux) -> nothing)) :: Tuple{Function, Function})
    (defaultTraceAuxillary, updateTraceAuxillary) = auxTuple
    # Update stack traces
    updateStackTraces(metadata.stackTraces, stackFrameIndex + 1, defaultTraceAuxillary, updateTraceAuxillary)
    # Update call counter
    metadata.callCount += 1
    # Update function specific data
    updateFuncSpecificData(metadata.funcSpecificData)
end

# Overrides eval to store metadata about calls to the function
function Core.eval(m::Module, @nospecialize(e))
    updateEvalInfo(evalInfo :: EvalInfo) = updateAstInfo(evalInfo.astHeads, e)
    updateTraceAuxillary(astHeads :: AstInfo) = updateAstInfo(astHeads, e)
    frameToGet = 3
    updateFuncMetadata(overrideInfo.evalInfo, frameToGet,
        updateEvalInfo; auxTuple=((() -> Dict{Symbol,Count}()), updateTraceAuxillary))
    storeOverrideInfo()

    # Original eval code
    ccall(:jl_toplevel_eval_in, Any, (Any, Any), m, e)
end

# Overrides invokelatest to store metadata about calls to the function
function Base.invokelatest(@nospecialize(f), @nospecialize args...; kwargs...)
    function updateInvokeLatestInfo(invokeLatestInfo :: InvokeLatestInfo)
        updateDictCount(invokeLatestInfo.funcNames, string(f))
    end
    updateTraceAuxillary(funcNames :: FunctionInfo) = updateDictCount(funcNames, string(f))
    frameToGet = 4
    updateFuncMetadata(overrideInfo.invokeLatestInfo, frameToGet,
        updateInvokeLatestInfo; auxTuple=((() -> Dict{String,Count}()), updateTraceAuxillary))
    storeOverrideInfo()

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
function storeOverrideInfo() :: Nothing
    OUTPUT_FILE = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"]).json"
    fd = open(OUTPUT_FILE, "w+")
    INDENT_SIZE = 2
    JSON.print(fd, overrideInfoToJson(overrideInfo), INDENT_SIZE)
    close(fd)
end

# Convert an OverrideInfo object to a julia json representation
function overrideInfoToJson(info :: OverrideInfo)
    json = Dict()
    json["eval_info"] = funcMetadataToJson(info.evalInfo,
        (evalInfo) -> astInfoToJson(evalInfo.astHeads);
        traceAuxillaryToJson=astInfoToJson)
    json["invokelatest_info"] = funcMetadataToJson(info.invokeLatestInfo,
        (invokeLatestInfo) -> Dict(["function_names" => countingDictToJson(invokeLatestInfo.funcNames, "function_name")]);
        traceAuxillaryToJson=funcInfoToJson)
    json
end

# Convert an astInfo object to a julia json representation
astInfoToJson(astHeads :: AstInfo) = Dict(["ast_heads" => countingDictToJson(astHeads, "ast_head")])

# Convert an functionInfo object to a julia json representation
funcInfoToJson(funcNames :: FunctionInfo) = Dict(["function_names" => countingDictToJson(funcNames, "function_name")])

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
