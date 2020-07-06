using Test

include("../../../src/test-gen/utils.jl")

@testset "test02" begin
  @test 2 == load("source.jl")
end
