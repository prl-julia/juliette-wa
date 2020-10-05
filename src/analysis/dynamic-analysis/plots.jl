using JSON, DataFrames, DataFramesMeta

const data_path = "C:\\Users\\Ben Chung\\Documents\\Work\\juliette-wa\\src\\analysis\\dynamic-analysis\\package-data"

pkgs = readdir(data_path)

const callinfo_regexp = r"(.*?) \[(.*?)( \(.*\))?\]"
function parse_callinfo(ci)
	matches = match(callinfo_regexp, ci)
	return (matches[1], matches[2] != "top", matches.captures[3] == nothing)
end

const tl_regexp = r"top-level scope.*"
function is_toplevel(lc)
	return occursin(tl_regexp, lc)
end

df = DataFrame(Package = String[], Context = String[], IsTopLevel = Bool[], Symbol=String[], Num = Int[])
for pkg in pkgs
	sourcefile = joinpath(data_path, pkg, "source.json")
	if !isfile(sourcefile)
		continue
	end
	json_data = JSON.parsefile(sourcefile)
	eval_data = json_data["eval_info"]
	il_data = json_data["invokelatest_info"]

	eval_stack_traces = eval_data["stack_traces"]
	for trace in eval_stack_traces
		auxd = trace["auxillary"]
		itl = is_toplevel(trace["last_call"])
		for dict in auxd["ast_heads"]
			for (k,v) in dict
				ci = parse_callinfo(k)
				push!(df, (pkg, trace["last_call"], itl, ci[1], v))
			end
		end
	end
end