#fails, too new
function g()
	eval(:(k() = 2))
	k()
end
g() # error
