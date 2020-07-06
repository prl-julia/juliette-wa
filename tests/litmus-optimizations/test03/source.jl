#---------------
# both inlining and direct call

h(y::Int64) = f(y) * g(y + y)

f(x::Any)   = 1
g(x::Int64) = x + f(x)
g(x::Any)   = 0

@assert h(3) == 7 # 1 * (6 + 1)

f(x::Any) = -1

@assert h(3) == -5 # -1 * (6 - 1)

f(x::Int64) = 2
g(x::Int64) = x - f(x)

h(3) # 8 because h(3) == 2 * (6 - 2)
