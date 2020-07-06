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
