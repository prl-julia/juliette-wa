using Test

include("../../utils.jl")

@testset "test01" begin
  @test "h" == get_methodvalue(load("source.jl"))
end
