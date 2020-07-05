using Test

include("../../utils.jl")

@testset "test01" begin
  @test_throws MethodError load("source.jl")
end
