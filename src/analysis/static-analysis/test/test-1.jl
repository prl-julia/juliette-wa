# GasModels exports everything except internal symbols, which are defined as
#...

const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]
for sym in names(@__MODULE__, all=true)
    sym_string = string(sym)
    if sym in _EXCLUDE_SYMBOLS || startswith(sym_string, "_")
        continue
    end
    if !(Base.isidentifier(sym) || (startswith(sym_string, "@") &&
         Base.isidentifier(sym_string[2:end])))
       continue
    end
    @eval export $sym
end


# the follow items are also exported for user-friendlyness when calling
# `using GasModels`

# so that users do not need to import JuMP to use a optimizer with GasModels
import JuMP: with_optimizer
export with_optimizer

for status_code_enum in [TerminationStatusCode, ResultStatusCode]
    for status_code in instances(status_code_enum)
        @eval import MathOptInterface: $(Symbol(status_code))
        @eval export $(Symbol(status_code))
    end
end

# Infrastructure Models Exports
export ids, ref, var, con, sol, nw_ids, nws, optimize_model!, ismultinetwork
