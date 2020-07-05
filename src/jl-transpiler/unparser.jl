
############
# Unparser #
############

# unparser: converts the given world-age program to a redex world age program
# as a string
unparser(expr :: WAAST) = "(term $(unparse(expr)))"

# unparse : converts the given world-age expression to its redex representation in string format
unparse(expr :: WANumber)   = string(expr.value)
unparse(expr :: WAString)   = "\"$(expr.value)\""
unparse(expr :: WABoolean)  = string(expr.value)
unparse(expr :: WAVariable) = string(expr.name)
unparse(expr :: WANothing)  = "nothing"
unparse(expr :: WAMethodVal)  = string(expr.value)
unparse(expr :: WAGlobalEval) = "(evalg $(unparse(expr.body)))"
unparse(expr :: WASequence)   =
    "(seq $(unparse(expr.first)) $(unparse(expr.second)))"
unparse(expr :: WAMethodDef)  =
    "(mdef \"$(expr.name)\" $(unparse_mdefparams(expr.parameters)) $(unparse(expr.body)))"
unparse(expr :: WACall) =
    unparse_call("mcall", unparse(expr.callee), unparse_mcallparams(expr.args))
unparse(expr :: WAPrimopCall) =
    unparse_call("pcall", "$(expr.callee)", unparse_mcallparams(expr.args))
unparse(expr :: WAIfThenElse) =
    "(if $(unparse(expr.conditional)) $(unparse(expr.iftrue)) $(unparse(expr.iffalse)))"

# unparse: converts the given type to its redex representation in string format
unparse(type :: WANumberType)  = "Number"
unparse(type :: WAIntType)     = "Int64"
unparse(type :: WAFloatType)   = "Float64"
unparse(type :: WABoolType)    = "Bool"
unparse(type :: WAStringType)  = "String"
unparse(type :: WANothingType) = "Nothing"
unparse(type :: WAAnyType)     = "Any"
unparse(type :: WABottomType)  = "Bot"
unparse(type :: MethodType)    = "(mtag \"$(type.methodname)\")"
unparse(type :: WAType)        = throw(WAMissingImplementation("$(type)"))

####################
# Unparser Helpers #
####################

# unparse_call: converts a the method call into a redex string by appending the
# three arguments together
unparse_call(calltype :: String, callee :: String, args :: String) =
    "($(calltype) $(callee)$(args))"

# unparse_mdefparams: converts the given vector of variable declarations in a
# method definition to its redex representation
function unparse_mdefparams(params :: Vector{Tuple{Symbol,WAType}})
    reduce_param((var,type),acc) = "(:: $(var) $(unparse(type))) $(acc)"
    unparsed_params = foldr(reduce_param, params; init="")
    "($(size(params)[1] == 0 ? unparsed_params : unparsed_params[1:end-1]))"
end

# unparse_mcallparams: converts the given vector of paramaters in a
# method call to its redex representation
function unparse_mcallparams(params :: Vector{WAAST})
    reduce_param(arg, acc) = " $(unparse(arg))$(acc)"
    unparsed_params = foldr(reduce_param, params; init="")
    "$(unparsed_params)"
end
