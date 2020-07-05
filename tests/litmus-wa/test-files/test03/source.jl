#succeeds, fixed with eval
function h()
	eval(:(j() = 2))
	eval(:(j()))
end
h() # == 2
