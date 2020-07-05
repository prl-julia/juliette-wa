using Test

include("../../utils.jl")

@testset "test08" begin
  @test_throws MethodError load("source.jl")
end
