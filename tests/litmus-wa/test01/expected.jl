using Test

include("../../../src/test-gen/utils.jl")

@testset "test01" begin
  @test_throws MethodError load("source.jl")
end
