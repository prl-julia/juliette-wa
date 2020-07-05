# Representable in Redex
##############################
#-------------
#fails, too new
function g()
  eval(:(k() = 2))
  k()
end
g() # error
#-------------
#succeeds, fixed with invokelatest
function h()
  eval(:(j() = 2))
  Base.invokelatest(j)
end
h() == 2
#-------------
#succeeds, fixed with eval
function h()
  eval(:(j() = 2))
  eval(:(j()))
end
h() == 2
#--------------
# fails, indirection doesn't help
r2() = r1()
function i()
  eval(:(r1() = 2))	
  r2()
end
i() # error
#--------------
# age propagates through calls
r4() = r3()
function m()
  eval(:(r3() = 2))	
  Base.invokelatest(r4)
end
m() == 2
#--------------
# succeeds, sequencing is different in eval/at top level
function l()
  eval(quote
    eval(:(f1() = 2))
    f1()
  end)
end
l() == 2
#--------------
# uses the orginal definition of g
g() = 2
f(x) = (
  eval(:(g() = $x));
  x * g()
)
f(42) == 84
#--------------
# uses the updated definition of g
g() = 2
f(x) = (
  eval(:(g() = $x));
  x * eval(:(g()))
f(42) == 1764
#--------------
# nested evals are all at the same top-level
f2() = eval(:(
 h1() = eval(:(h2() = 2));
 h1();
 h2()
))
f2() == 2
#--------------
# fails, function too new
f3() = begin
 h1() = (eval(:(h3() = 2)); h3());
 h1()
end
f3()
#--------------
# fails, variable x not found
function f4(x)
  eval(:(x))
end 
f4(0)

# Not representable in Redex
##############################
#--------------
# eval changes global variable
x = 1
f(x) = (
  eval(:(x = 0));
  x * 2
)
f(42) == 84
x == 0

