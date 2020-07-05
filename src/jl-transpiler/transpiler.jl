
##############
# transpiler #
##############

# transpile: converts a julia program in string format to a world-age
# redex program also in string format
transpile(julia :: String) :: String = 
    unparser(parser(Meta.parse("begin\n$(julia)\nend")))
