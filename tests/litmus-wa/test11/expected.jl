using Test

include("../../../src/test-gen/utils.jl")

@testset "test11" begin
  @test true == load("source.jl")
end
