using Test

include("../../../src/test-gen/utils.jl")

@testset "test12" begin
  @test_throws TypeError load("source.jl")
end
