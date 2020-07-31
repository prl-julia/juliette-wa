f() = eval(:(g() = 6))

for i in 1:5
  Core.eval(Main, :(println($i)))
  @eval f()
  @eval(Main, 3)
end

myeval(3)

Core.eval(m, "x")
