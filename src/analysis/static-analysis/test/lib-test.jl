using Test

include("../lib/analysis.jl")

const DEFAULT_ARG_CTX = EvalArgContext(false, false)

@testset "nonVacuous" begin
    @test !nonVacuous(Stat(0, 0))
    @test nonVacuous(Stat(1, 0))
    @test nonVacuous(Stat(0, 1))
    @test nonVacuous(Stat(5, 2))
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

parseTestFile(fname :: String) = parseJuliaFile(joinpath(@__DIR__, fname))

@testset "countEval" begin
    # hand-written
    @test countEval(parseTestFile("test-0.jl")) == 5
    # from GasModels.jl (reduced src/core/export.jl)
    @test countEval(parseTestFile("test-1.jl")) == 3
    # from Symata.jl (reduced src/math_functions.jl)
    @test countEval(parseTestFile("test-2.jl")) == 18
    # from CUDA.jl (reduced src/device/intrinsics/atomics.jl)
    @test countEval(parseTestFile("test-3.jl")) == 9
    # from Genie.jl (reduced src/renderers/Html.jl)
    @test countEval(parseTestFile("test-4.jl")) == 9
end

@testset "argDescr" begin
    @test argDescr(5) == [EvalCallInfo(:value, DEFAULT_ARG_CTX)]
    @test argDescr(:(const F = 1), EvalArgContext(true, false)) == 
            [EvalCallInfo(:const, EvalArgContext(true, false))]
    @test argDescr(:(f() = 0)) == [EvalCallInfo(:function, DEFAULT_ARG_CTX)]
    @test argDescr(:(x = 666)) == [EvalCallInfo(:(=), DEFAULT_ARG_CTX)]
    @test argDescr(:(eval(:( f() = 0 ))).args[2], DEFAULT_ARG_CTX) == 
            [EvalCallInfo(:function, EvalArgContext(false, true))]
end

@testset "getEvalInfo" begin
    @test getEvalInfo(:(eval(:( f() = 0 )))) ==
        [EvalCallInfo(:function, EvalArgContext(false, true))]
    @test getEvalInfo(:(eval(:( y = 1 )))) ==
        [EvalCallInfo(:(=), EvalArgContext(false, true))]
    @test getEvalInfo(:(eval())) == [EvalCallInfo(:nothing, DEFAULT_ARG_CTX)]
    @test getEvalInfo(:(eval(3))) == [EvalCallInfo(:value, DEFAULT_ARG_CTX)]
    @test getEvalInfo(:(Core.eval(Main, 3))) == [EvalCallInfo(:value, DEFAULT_ARG_CTX)]
    @test getEvalInfo(:(@eval y = 1)) == [EvalCallInfo(:(=), DEFAULT_ARG_CTX)]
    @test getEvalInfo(:(@eval(Main, y = 1))) == [EvalCallInfo(:(=), DEFAULT_ARG_CTX)]
end

@testset "gatherEvalInfo" begin
    @test gatherEvalInfo(:(eval()), EvalArgContext(true, false)) ==
            [EvalCallInfo(:nothing, EvalArgContext(true, false))]
    @test gatherEvalInfo(:((eval(); @eval 1))) ==
            [EvalCallInfo(:nothing, DEFAULT_ARG_CTX),
             EvalCallInfo(:value, EvalArgContext(false, true))]
end
