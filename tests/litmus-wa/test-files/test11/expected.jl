using Test

include("../../utils.jl")

@testset "test11" begin
  @test true == load("source.jl")
end
