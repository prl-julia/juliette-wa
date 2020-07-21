######################################
# Override Eval and InvokeLatest Code
######################################

# Represents a counter
Count = Int64

# Represents the information collected regarding eval function calls
mutable struct EvalInfo
    astHeads :: Dict{Symbol, Count}
end

# Represents the information collected regarding eval function calls
mutable struct InvokeLatestInfo
    funcNames :: Dict{String, Count}
end

# Represents the information collected regarding overriden function calls
mutable struct FuncMetadata{T}
    callCount :: Int64
    stackTraces :: Dict{StackTraces.StackFrame, Count}
    funcSpecificData :: T
end
# Initializes a base representation of function metadata
FuncMetadata(funcSpecificData) = FuncMetadata(0, Dict{StackTraces.StackFrame, Count}(), funcSpecificData)

# Represents the information being analyzed when running packages
mutable struct OverrideInfo
    evalInfo :: FuncMetadata{EvalInfo}
    invokeLatestInfo :: FuncMetadata{InvokeLatestInfo}
end

# Initialize empty overrideInfo
overrideInfo = OverrideInfo(FuncMetadata(EvalInfo(Dict())),
                            FuncMetadata(InvokeLatestInfo(Dict())))

# Adds one to the value of the key, creates keys with value of 1 if it does not already exist
updateDictCount(dict :: Dict{T, Count}, key :: T) where {T} = dict[key] = get!(dict, key, 0) + 1

# Updates the information for a new call to a function being analyzed
function updateFuncMetadata(metadata :: FuncMetadata, stackFrameIndex :: Int64, updatefuncSpecificData :: Function) :: Nothing
    traceNoCurrentFrame = getindex(stacktrace(), stackFrameIndex)
    updateDictCount(metadata.stackTraces, traceNoCurrentFrame)
    metadata.callCount += 1
    updatefuncSpecificData(metadata.funcSpecificData)
    nothing
end

# Overrides eval to store metadata about calls to the function
function Core.eval(m::Module, @nospecialize(e))
    function updateEvalInfo(evalInfo :: EvalInfo)
        currAstHead = typeof(e) == Expr ? e.head : :PrimitiveValue
        updateDictCount(evalInfo.astHeads, currAstHead)
    end
    updateFuncMetadata(overrideInfo.evalInfo, 3, updateEvalInfo)

    # Original eval code
    ccall(:jl_toplevel_eval_in, Any, (Any, Any), m, e)
end

# Overrides invokelatest to store metadata about calls to the function
function Base.invokelatest(@nospecialize(f), @nospecialize args...; kwargs...)
    function updateInvokeLatestInfo(invokeLatestInfo :: InvokeLatestInfo)
        updateDictCount(invokeLatestInfo.funcNames, string(f))
    end
    updateFuncMetadata(overrideInfo.invokeLatestInfo, 4, updateInvokeLatestInfo)

    # Original invokelatest code
    if isempty(kwargs)
        return Core._apply_latest(f, args)
    end
    # We use a closure (`inner`) to handle kwargs.
    inner() = f(args...; kwargs...)
    Core._apply_latest(inner)
end

############################
# OverrideInfo to JSON Code
############################

using Pkg
Pkg.add("JSON")
using JSON

# Store the overrideInfo as a JSON file
function storeOverrideInfo(info :: OverrideInfo, filename :: String) :: Nothing
    OUTPUT_FILE = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(filename).json"
    fd = open(OUTPUT_FILE, "w+")
    JSON.print(fd, overrideInfoToJson(info), 2)
    close(fd)
end

# Convert an OverrideInfo object to a julia json representation
function overrideInfoToJson(info :: OverrideInfo)
    json = Dict()
    json["eval_info"] = funcMetadataToJson(info.evalInfo,
        (evalInfo) -> Dict(["ast_heads" => countingDictToJson(evalInfo.astHeads, "ast_head")]))
    json["invokelatest_info"] = funcMetadataToJson(info.invokeLatestInfo,
        (invokeLatestInfo) -> Dict(["function_names" => countingDictToJson(invokeLatestInfo.funcNames, "function_name")]))
    json
end

# Convert an FuncMetadata object to a julia json representation
function funcMetadataToJson(funcMetadata :: FuncMetadata, funcSpecificDataToJson :: Function)
    json = Dict()
    json["call_count"] = funcMetadata.callCount
    json["stack_traces"] = countingDictToJson(funcMetadata.stackTraces, "last_call")
    json["func_specific_data"] = funcSpecificDataToJson(funcMetadata.funcSpecificData)
    json
end

# Convert a dictionary counting instance occurances to a sorted julia json representation
function countingDictToJson(dict :: Dict{T, Count}, keyName :: String) where {T}
    sortedDict = sort!(collect(dict), by = pair -> pair.second, rev = true)
    function dictToJson((key, count), acc)
        append!([Dict(["count" => count, keyName => string(key)])], acc)
    end
    foldr(dictToJson, sortedDict; init = [])
end
