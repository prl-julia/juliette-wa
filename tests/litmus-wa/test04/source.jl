# fails, indirection doesn't help
r2() = r1()
function i()
  eval(:(r1() = 2))	
  r2()
end
i() # error
