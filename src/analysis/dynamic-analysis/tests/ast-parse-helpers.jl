include("../ast-parse-helpers.jl")
using Test

#################
# Test Helpers
#################

macro parse(ast)
    return :(Meta.parse($ast))
end

#############
# Examples
#############

ast_num = @parse "1"
ast_bool = @parse "true"
ast_func = @parse "function func(fake :: Bool) :: String 1 end"
ast_abreviated_func = @parse "func() = 1"
ast_lambda_func = @parse "() -> 1"
ast_lambda_binding = @parse "hey = () -> 1"
ast_bodyless_func = @parse "function func end"
ast_block = @parse "(1;true;f())"
ast_block_nested = @parse "((1);(g()=1;nothing))"

ast_extract_1 = @parse "1"
ast_extract_true = @parse "true"
ast_extract_fcall = @parse "f()"
ast_extract_gdef = @parse "g()=1"
ast_extract_nothing = @parse "nothing"

ast_extract_block = [ast_extract_1, ast_extract_true, ast_extract_fcall]
ast_extract_block_nested = [ast_extract_1, ast_extract_gdef, ast_extract_nothing]

ast_abbreviated_base_def = @parse "Base.show(var :: Int64) = 1"
ast_base_def = @parse "function Base.show() :: String 1 end"


##########
# Tests
##########

@testset "AST parser tests" begin
    @test isAstWithBody(ast_num, :call) == false
    @test isAstWithBody(ast_bool, :(=)) == false
    @test isAstWithBody(ast_func, :function) == true
    @test isAstWithBody(ast_abreviated_func, :function) == false
    @test isAstWithBody(ast_bodyless_func, :function) == true

    @test isAbreviatedFunc(ast_func) == false
    @test isAbreviatedFunc(ast_abreviated_func) == true
    @test isAbreviatedFunc(ast_bodyless_func) == false

    @test isLambdaFunc(ast_func) == false
    @test isLambdaFunc(ast_abreviated_func) == false
    @test isLambdaFunc(ast_lambda_func) == true

    @test isLambdaBinding(ast_lambda_func) == false
    @test isLambdaBinding(ast_lambda_binding) == true
    @test isLambdaBinding(ast_bodyless_func) == false

    @test isIrregularFunction(ast_func) == false
    @test isIrregularFunction(ast_abreviated_func) == true
    @test isIrregularFunction(ast_lambda_func) == true
    @test isIrregularFunction(ast_lambda_binding) == true
    @test isIrregularFunction(ast_bodyless_func) == false

    @test extractExprs(ast_num) == [ast_num]
    @test extractExprs(ast_func) == [ast_func]
    @test extractExprs(ast_block) == ast_extract_block
    @test extractExprs(ast_block_nested) == ast_extract_block_nested

    @test getFuncNameAndModule(ast_func, eval(:Core)) == (eval(:Core), :func)
    @test getFuncNameAndModule(ast_abreviated_func, eval(:Base)) == (eval(:Base), :func)
    @test getFuncNameAndModule(ast_base_def, eval(:Core)) == (eval(:Base), :show)
    @test getFuncNameAndModule(ast_abbreviated_base_def, eval(:Core)) == (eval(:Base), :show)

end
