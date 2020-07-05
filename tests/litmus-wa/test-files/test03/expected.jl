using Test

include("../../utils.jl")

@testset "test03" begin
  @test 2 == load("source.jl")
end
