using Test

include("../../utils.jl")

@testset "paper02" begin
  @test 1764 == load("source.jl")
end
