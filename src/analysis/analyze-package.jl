include("test-override.jl")
using Pkg

fd = open("C:/Users/gelin/Documents/computer-science/research/julia/juliette-wa/src/analysis/output.json"; truncate=true)
close(fd)
Pkg.add("Printf")
Pkg.test("Printf")
# Pkg.add("Revise")
# Pkg.test("Revise")
