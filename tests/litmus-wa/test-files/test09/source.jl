# fails, variable not found
function f4(x)
  eval(:(x))
end
f4(0)
