using Test

include("../../utils.jl")

@testset "test09" begin
  @test_throws UndefVarError load("source.jl")
end
