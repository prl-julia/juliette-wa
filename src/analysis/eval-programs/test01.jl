
# Determines if the given number is even
even(val :: Int64) :: Bool = val == 0 ? true : odd(val - 1)

# Determines if the given number is odd
odd(val :: Int64) :: Bool = val == 0 ? false : even(val - 1)

# Computes the next number in the collatz sequence for the given number
collatzStep(val :: Int64) :: Int64 = even(val) ? val/2 : (3 * val) + 1

# Computes the collatz sequence for the given number
function collatzRun(val :: Int64) :: Vector{Int64}
    trace = [val]
    while val != 1
        val = collatzStep(val)
        append!(trace, val)
    end
    trace
end

# Determines the percent of even and odd numbers in the given set of numbers
function evenOddDistro(numSet :: Vector{Int64}) :: Tuple{Float64, Float64}
    countEvens = (num, acc) -> acc + (even(num) ? 1 : 0)
    evenCount = foldr(countEvens, numSet; init=0)
    evenPercent = round((evenCount / size(numSet)[1]) * 100, digits=3)
    oddPercent = 100 - evenPercent
    (evenPercent, oddPercent)
end

# Determines the percent of even and odd numbers in a collatz sequence for the given number
function evenOddDistroOfCollatz(val :: Int64) :: Nothing
    (evenPercent, oddPercent) = evenOddDistro(collatzRun(val))
    outMessage = "$(val): even=$(evenPercent)%, odd=$(oddPercent)%"
    println(outMessage)
end

evenOddDistroOfCollatz(1)
evenOddDistroOfCollatz(7)
evenOddDistroOfCollatz(22)
