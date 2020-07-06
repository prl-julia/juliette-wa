using Test

include("../../../src/test-gen/utils.jl")

@testset "test01" begin
  @test "h" == get_methodvalue(load("source.jl"))
end
