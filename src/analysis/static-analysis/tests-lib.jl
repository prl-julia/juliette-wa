using Test

include("lib.jl")

@testset "nonVacuous" begin
    @test nonVacuous(Stat(0, 0)) == false
    @test nonVacuous(Stat(1, 0)) == true
    @test nonVacuous(Stat(0, 1)) == true
    @test nonVacuous(Stat(5, 2)) == true
end

@testset "evalName" begin
    @test isEvalName(:eval)
    @test isEvalName(:(eval(:(3))).args[1])
    @test isEvalName(:(Core.eval))
    @test isEvalName(:(Core.eval(:("x"))).args[1])

    @test isEvalMacroName(Symbol("@eval"))
end

@testset "isEvalCall" begin
    @test isEvalCall(:(eval(3)))
    @test isEvalCall(:(Core.eval(Main, 3)))
    @test isEvalCall(:(@eval 5))
    @test isEvalCall(:(@eval(Main, 4+2)))
    @test isEvalCall(Meta.parse("@eval"))
end

@testset "countEval" begin
    # hand-written
    @test countEval(parseJuliaFile("test/test-0.jl")) == 5
    # from GasModels.jl (reduced src/core/export.jl)
    @test countEval(parseJuliaFile("test/test-1.jl")) == 3
    # from Symata.jl (reduced src/math_functions.jl)
    @test countEval(parseJuliaFile("test/test-2.jl")) == 18
    # from CUDA.jl (reduced src/device/intrinsics/atomics.jl)
    @test countEval(parseJuliaFile("test/test-3.jl")) == 9
    # from Genie.jl (reduced src/renderers/Html.jl)
    @test countEval(parseJuliaFile("test/test-4.jl")) == 9
end