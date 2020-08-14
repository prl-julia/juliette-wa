using Pkg
Pkg.add("JSON")
using JSON

# Store the overrideInfo as a JSON file
function storeOverrideInfo(overrideInfo :: OverrideInfo, outputFile :: String)
    fd = open(outputFile, "w+")
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
