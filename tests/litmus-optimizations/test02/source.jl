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
