using Test

include("../../utils.jl")

@testset "test04" begin
  @test_throws MethodError load("source.jl")
end
