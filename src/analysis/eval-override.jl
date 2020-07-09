
const EVAL_PROGRAMS_DIR = "eval-programs"

struct EvalInfo
    callCount :: Int64
end

try
    for file = readdir(EVAL_PROGRAMS_DIR)
        evalInfo = EvalInfo(0)
        function Core.eval(m::Module, @nospecialize(e))
          evalInfo = EvalInfo(evalInfo.callCount + 1)
          ccall(:jl_toplevel_eval_in, Any, (Any, Any), m, e)
        end
        include("eval-programs/$(file)")
        println(evalInfo)
    end
catch e
    println(e)
end
