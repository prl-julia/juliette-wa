using Test

include("lib.jl")

@testset "isIntersting" begin
    @test isInteresting(FileStat(0, 0)) == false
    @test isInteresting(FileStat(1, 0)) == true
    @test isInteresting(FileStat(0, 1)) == true
    @test isInteresting(FileStat(5, 2)) == true
end