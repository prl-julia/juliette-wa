using Test

include("../../../src/test-gen/utils.jl")

@testset "paper01" begin
  @test 8 == load("source.jl")
end
