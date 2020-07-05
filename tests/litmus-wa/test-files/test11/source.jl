#succeeds, fixed with invokelatest
function h(bool :: Bool)
	if bool
		eval(:(j() = 1))
	else
		eval(:(j() = 2))
	end
	Base.invokelatest(j)
end
h(true) == 1 && h(false) == 2
