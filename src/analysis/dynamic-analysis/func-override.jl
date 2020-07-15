######################################
# Override Eval and InvokeLatest Code
######################################

# Represents a counter
#####################@TODO UInt
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

#@TODO look at first frame of trace
#@TODO Unique environments
function updateFuncMetadata(metadata :: FuncMetadata, updatefuncSpecificData :: Function) :: Nothing
    traceNoCurrentFrame = getindex(stacktrace(), 3)
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
    updateFuncMetadata(overrideInfo.evalInfo, updateEvalInfo)

    # Original eval code
    ccall(:jl_toplevel_eval_in, Any, (Any, Any), m, e)
end

# Overrides invokelatest to store metadata about calls to the function
function Base.invokelatest(@nospecialize(f), @nospecialize args...; kwargs...)
    function updateInvokeLatestInfo(invokeLatestInfo :: InvokeLatestInfo)
        updateDictCount(invokeLatestInfo.funcNames, string(f))
    end
    updateFuncMetadata(overrideInfo.invokeLatestInfo, updateInvokeLatestInfo)

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

const OUTPUT_FILE = "$(pwd())/output.json"

function storeOverrideInfo(info :: OverrideInfo) :: Nothing
    fd = open(OUTPUT_FILE, "a")
    JSON.print(fd, overrideInfoToJson(info), 2)
    close(fd)
end

function overrideInfoToJson(info :: OverrideInfo)
    json = Dict()
    json["eval_info"] = funcMetadataToJson(info.evalInfo,
        (evalInfo) -> Dict(["ast_heads" => countingDictToJson(evalInfo.astHeads, "ast_head")]))
    json["invokelatest_info"] = funcMetadataToJson(info.invokeLatestInfo,
        (invokeLatestInfo) -> Dict(["function_names" => countingDictToJson(invokeLatestInfo.funcNames, "function_name")]))
    json
end

function funcMetadataToJson(funcMetadata :: FuncMetadata, funcSpecificDataToJson :: Function)
    json = Dict()
    json["call_count"] = funcMetadata.callCount
    json["stack_traces"] = countingDictToJson(funcMetadata.stackTraces, "last_call")
    json["func_specific_data"] = funcSpecificDataToJson(funcMetadata.funcSpecificData)
    json
end

function countingDictToJson(dict :: Dict{T, Count}, keyName :: String) where {T}
    sortedDict = sort!(collect(dict), by = pair -> pair.second, rev = true)
    function dictToJson((key, count), acc)
        append!([Dict(["count" => count, keyName => string(key)])], acc)
    end
    foldr(dictToJson, sortedDict; init = [])
end

# function stackTracesToJson(stackTraces :: Dict{StackTraces.StackTrace, Int})
#     sortedStackTraces = sort!(collect(stackTraces), by = pair -> pair.second, rev = true)
#     function stacktraceToJson((trace, count), acc)
#         append!([Dict(["trace_count" => count, "stack_trace" => string(trace)])], acc)
#     end
#     foldr(stacktraceToJson, sortedStackTraces; init = [])
# end
