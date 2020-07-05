# fails, function too new
f3() = begin
 h1() = (eval(:(h3() = 2)); h3());
 h1()
end
f3()
