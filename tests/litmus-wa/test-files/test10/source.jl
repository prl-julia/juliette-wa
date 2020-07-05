#passes, fixed with eval
function g()
  eval(:(k() = eval(:(h() = 1))))
  eval(:(k()))
end
g() # (mval "h")
