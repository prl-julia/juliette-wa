using Test

include("lib.jl")

@testset "nonVacuous" begin
    @test nonVacuous(FileStat(0, 0)) == false
    @test nonVacuous(FileStat(1, 0)) == true
    @test nonVacuous(FileStat(0, 1)) == true
    @test nonVacuous(FileStat(5, 2)) == true
end