# Inlining and Direct Call Optimizations
##############################

#---------------
# simple inlining is correct even on redefinition

f(x::Any)     = "f-any"
f(x::Int64)   = "f-int"

h(x::Float64) = f(x)
h(x::Any)     = "h-any"

@assert h(3.14) == "f-any"
@assert h(413)  == "h-any"

f(x::Float64) = "f-float"

@assert h(3.14) == "f-float"

h(x::Float64) = 777

h(3.14) # 777

#---------------
# simple direct call is correct even on redefinition

f(x::Any)     = "f-any"
f(x::Int64)   = "f-int"

h(x::Float64) = f(x + x)
h(x::Any)     = "h-any"

@assert h(3.14) == "f-any"
@assert h(413)  == "h-any"

f(x::Float64) = "f-float"

@assert h(3.14) == "f-float"

h(x::Float64) = 777

h(3.14) # 777

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

#---------------
# recursion and direct call

odd( x::Any)   = "boo-odd"
even(x::Any)   = "boo-even"

@assert odd(7) == "boo-odd"

odd( x::Int64) = oddp(x >= 0 ? x : -x)
even(x::Int64) = x >= 0 ? evenp(x) : evenp(-x)

oddp( x::Int64) = x == 1 ? true  : (x == 0 ? false : even(x - 1))
evenp(x::Int64) = x == 1 ? false : (x == 0 ? true  : odd(x - 1))

@assert odd(  7) == true
@assert odd( -7) == true
@assert even(-7) == false

oddp(x::Int64)  = "oddp"

@assert odd( -7) == "oddp"
@assert even(-7) == "oddp"
@assert even(-1) == false

even(0) # true
