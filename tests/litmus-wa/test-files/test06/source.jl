# succeeds, sequencing is different in eval/at top level
function l()
  eval(quote
    eval(:(f1() = 2))
    f1()
  end)
end
l() # == 2
