using Test

include("../../../src/test-gen/utils.jl")

@testset "test07" begin
  @test 2 == load("source.jl")
end
