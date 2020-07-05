# age propagates through calls
r3() = r2()
function m()
  eval(:(r2() = 2))	
  Base.invokelatest(r3)
end
m() # == 2
