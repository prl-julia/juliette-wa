using Test

include("../../../src/test-gen/utils.jl")

@testset "test09" begin
  @test_throws UndefVarError load("source.jl")
end
