
# Buggy methods
first() = 3
second() = 2
third() = 1
funcList = [first, second, third]

# Calls each function in a list of functions
callFunctionList(buggyList :: Vector{Function}) = println(map(f -> f(), buggyList))

# A very very very specific method that
function fixBuggyList(buggyList :: Vector{Function}) :: Nothing
    callFunctionList(buggyList)
    println("Oh shoot, these methods print backwards. Lets fix it!")
    eval(:(first() = 1))
    eval(:(second() = 2))
    eval(:(third() = 3))
    callFunctionList(buggyList)
    println("Give it a sec, fix pending on world age")
end

# Run bug fixer
fixBuggyList(funcList)
println("There, that should be better")
callFunctionList(funcList)
