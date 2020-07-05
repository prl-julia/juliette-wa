using Test

include("../../utils.jl")

@testset "paper01" begin
  @test 84 == load("source.jl")
end
