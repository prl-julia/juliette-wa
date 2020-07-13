# Prints error message and terminates execution
function exitErrWithMsg(msg :: String)
    println(stderr, "ERROR: $(msg)")
    exit(1)
end
