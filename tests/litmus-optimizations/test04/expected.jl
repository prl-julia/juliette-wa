using Test

include("../../../src/test-gen/utils.jl")

@testset "paper01" begin
  @test true == load("source.jl")
end
