#succeeds, fixed with invokelatest
function h()
	eval(:(j() = 2))
	Base.invokelatest(j)
end
h() # == 2
