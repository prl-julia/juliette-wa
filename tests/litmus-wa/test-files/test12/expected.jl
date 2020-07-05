using Test

include("../../utils.jl")

@testset "test12" begin
  @test_throws TypeError load("source.jl")
end
