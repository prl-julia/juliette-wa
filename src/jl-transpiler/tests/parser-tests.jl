########################
# Environment Examples #
########################

env_mt = EmptyStack{ScopeComponent}()
env_varx = NonEmptyStack{ScopeComponent}(LocalVar(:x, Symbol("1_x")), env_mt)
env_varvar = NonEmptyStack{ScopeComponent}(LocalVar(:var, Symbol("1_var")), env_varx)

######################
# Julia-AST Examples #
######################

jul_int1 = :(1)
jul_int11 = :(11)
jul_floatpi = :(3.14)
jul_intneg1 = :(-1)

jul_stra = :("a")
jul_strabc = :("abc")
jul_strmany = :("this string #'s and spaces 123")

jul_btrue = :(true)
jul_bfalse = :(false)

jul_varx = :(x)
jul_varvar = :(var)

jul_noth = :(nothing)

jul_mvalf = :(f)
jul_mvalcomp = :(compose)

jul_seq1 = quote (1;true) end
jul_seq2 = quote (x;1;true) end
jul_seq3 = quote ($jul_seq2;nothing) end
jul_seq4 = quote (compose) end
jul_seq5 = quote begin end end

jul_call1 = quote $jul_mvalf($jul_seq3, $jul_floatpi) end
jul_call2 = quote true() end
jul_call3 = quote f(-1) end

jul_eval1 = quote eval($jul_strmany) end
jul_eval2 = quote eval($jul_eval1) end
jul_eval3 = quote Base.invokelatest($jul_mvalf, $jul_seq3, $jul_floatpi) end

jul_mdef1 = quote f() = 1 end
jul_mdef2 = quote g(x, y :: Int64) = x + y end
jul_mdef3 = quote
                function f(g :: typeof(h))
                    return g(1, true)
                end
            end
jul_mdef4 = quote
                function compose(f, g)
                    h(x) = f(g(x))
                    return h
                end
            end
jul_mdef5 = quote
                function big(a::Bool,b::Any,c::Nothing,d::Number,e::Int64,
                            f::Float64,g::String,h::Union{},i::typeof(compose))
                    "a"
                end
            end
jul_mdef6 = quote f() = nothing end
jul_call8 = quote print(-1) end
jul_call9 = quote -1 * 5 end
jul_call10 = quote 11 / 1 end
jul_call11 = quote 11 - 1 end
jul_call12 = quote true && false end
jul_call13 = quote false || false end
jul_call14 = quote !true end
jul_if1 = quote
                if 1 == 2
                    4
                else
                    5
                end
          end
jul_if2 = quote
              if 1 == 2
                  4
              elseif false == "a"
                  5
              elseif true
                  3
              end
        end
jul_if3 = quote s ? "a" : true end
jul_if4 = quote
                if 1 == 2
                    4
                end
          end
jul_if5 = quote
            if 1 == 2
                4
            elseif false == "a"
                5
            else
                3
            end
      end

##########################
# World-Age-AST Examples #
##########################

# Types
booltype = WABoolType()
anytype = WAAnyType()
nothingtype = WANothingType()
numberType = WANumberType()
inttype = WAIntType()
floattype = WAFloatType()
stringtype = WAStringType()
bottomtype = WABottomType()
methodtypeh = MethodType(:h)
methodtype2 = MethodType(:compose)

# Expressions
int1 = WANumber(1)
int2 = WANumber(2)
int11 = WANumber(11)
int5 = WANumber(5)
floatpi = WANumber(3.14)
intneg1 = WANumber(-1)

stra = WAString("a")
strabc = WAString("abc")
strmany = WAString("this string #'s and spaces 123")

btrue = WABoolean(true)
bfalse = WABoolean(false)

var1 = WAVariable(:var1)
var2 = WAVariable(:var2)
var3 = WAVariable(:var3)
varname = WAVariable(:name)
varx = WAVariable(Symbol("1_x"))
vary = WAVariable(Symbol("1_y"))
varz = WAVariable(Symbol("1_z"))
varf = WAVariable(Symbol("1_f"))
varg = WAVariable(Symbol("1_g"))
varvar = WAVariable(Symbol("1_var"))

noth = WANothing()

mvalvar1 = WAVariable(:var1)
mvals = WAVariable(:s)
mvalf = WAVariable(Symbol("f"))
mvalg = WAVariable(:g)
mvalh = WAVariable(Symbol("h"))
mvalvar4 = WAVariable(:var4)
mvalcomp = WAVariable(:compose)
mvaladd = WAVariable(:+)
mvalprint = WAVariable(:print)

seq1 = WASequence(int1, btrue)
seq2 = WASequence(varx, seq1)
seq3 = WASequence(seq2, noth)

call1 = WACall(mvalf, [seq3, floatpi])
call2 = WACall(btrue, [])
call3 = WACall(mvalf, [intneg1])
call4 = WAPrimopCall(:+, [varx, vary])
call5 = WACall(varg, [int1, btrue])

eval1 = WAGlobalEval(strmany)
eval2 = WAGlobalEval(eval1)
eval3 = WAGlobalEval(call1)

mdef1 = WAMethodDef(:f, [], int1)
mdef2 = WAMethodDef(:g, [(Symbol("1_x"),anytype), (Symbol("1_y"),inttype)], call4)
mdef3 = WAMethodDef(:f, [(Symbol("1_g"),methodtypeh)], call5)

call6 = WACall(varg, [WAVariable(Symbol("1_x"))])
call7 = WACall(varf, [call6])
mdef4_a = WAMethodDef(:h, [(Symbol("1_x"),anytype)], call7)
seq4 = WASequence(mdef4_a, mvalh);
mdef4 = WAMethodDef(:compose, [(Symbol("1_f"),anytype),(Symbol("1_g"),anytype)], seq4)

mdef5 = WAMethodDef(:big,
        [
            (Symbol("1_a"),booltype),(Symbol("1_b"),anytype),(Symbol("1_c"),nothingtype),(Symbol("1_d"),numberType),(Symbol("1_e"),inttype),
            (Symbol("1_f"),floattype),(Symbol("1_g"),stringtype),(Symbol("1_h"),bottomtype),(Symbol("1_i"),methodtype2)
        ],
        stra
    )
mdef6 = WAMethodDef(:f, [], noth)
call8 = WAPrimopCall(:print, [intneg1])
call9 = WAPrimopCall(:*, [intneg1, int5])
call10 = WAPrimopCall(:/, [int11, int1])
call11 = WAPrimopCall(:-, [int11, int1])
call12 = WAPrimopCall(:&&, [btrue, bfalse])
call13 = WAPrimopCall(:||, [bfalse, bfalse])
call14 = WAPrimopCall(:!, [btrue])

if1 = WAIfThenElse(WAPrimopCall(:(==), [WANumber(1), WANumber(2)]), WANumber(4), WANumber(5))
if2 = WAIfThenElse(WAPrimopCall(:(==), [WANumber(1), WANumber(2)]), WANumber(4),
        WAIfThenElse(WAPrimopCall(:(==), [WABoolean(false), WAString("a")]), WANumber(5),
            WAIfThenElse(WABoolean(true), WANumber(3), WANothing())))
if3 = WAIfThenElse(WAVariable(:s), WAString("a"), WABoolean(true))
if4 = WAIfThenElse(WAPrimopCall(:(==), [WANumber(1), WANumber(2)]), WANumber(4), WANothing())
if5 = WAIfThenElse(WAPrimopCall(:(==), [WANumber(1), WANumber(2)]), WANumber(4),
        WAIfThenElse(WAPrimopCall(:(==), [WABoolean(false), WAString("a")]), WANumber(5),
            WANumber(3)))

################
# Test Helpers #
################

==(ast1 :: WAAST, ast2 :: WAAST) = genericStructEqual(ast1, ast2)

function juliatoWA_wrap(expr) :: WAAST
    return juliatoWA(expr, Env())
end

function juliatoWA_wrapenv(expr, scope :: ImmutableStack{ScopeComponent}) :: WAAST
    return juliatoWA(expr, Env(scope))
end

#########
# Tests #
#########

using Test

@testset "Base case juliatoWA tests" begin
    @test juliatoWA_wrap(jul_int1) == int1
    @test juliatoWA_wrap(jul_int11) == int11
    @test juliatoWA_wrap(jul_floatpi) == floatpi
    @test juliatoWA_wrap(jul_intneg1) == intneg1
    @test juliatoWA_wrap(jul_stra) == stra
    @test juliatoWA_wrap(jul_strabc) == strabc
    @test juliatoWA_wrap(jul_strmany) == strmany
    @test juliatoWA_wrap(jul_btrue) == btrue
    @test juliatoWA_wrap(jul_bfalse) == bfalse
    @test juliatoWA_wrapenv(jul_varx, env_varx) == varx
    @test juliatoWA_wrapenv(jul_varvar, env_varvar) == varvar
    @test juliatoWA_wrap(jul_noth) == noth
    @test juliatoWA_wrap(jul_mvalf) == mvalf
    @test juliatoWA_wrap(jul_mvalcomp) == mvalcomp
end

@testset "Recursive case juliatoWA tests" begin
    @test juliatoWA_wrap(jul_seq1) == seq1
    @test juliatoWA_wrapenv(jul_seq2, env_varx) == seq2
    @test juliatoWA_wrapenv(jul_seq3, env_varvar) == seq3
    @test juliatoWA_wrap(jul_seq4) == mvalcomp
    @test juliatoWA_wrap(jul_seq5) == noth
    @test juliatoWA(jul_call1, Env(env_varvar)) == call1
    @test juliatoWA_wrap(jul_call2) == call2
    @test juliatoWA_wrap(jul_call3) == call3
    @test juliatoWA_wrap(jul_call8) == call8
    @test juliatoWA_wrap(jul_call9) == call9
    @test juliatoWA_wrap(jul_call10) == call10
    @test juliatoWA_wrap(jul_call11) == call11
    @test juliatoWA_wrap(jul_call12) == call12
    @test juliatoWA_wrap(jul_call13) == call13
    @test juliatoWA_wrap(jul_call14) == call14
    @test juliatoWA_wrap(jul_if1) == if1
    @test juliatoWA_wrap(jul_if2) == if2
    @test juliatoWA_wrap(jul_if3) == if3
    @test juliatoWA_wrap(jul_if4) == if4
    @test juliatoWA_wrap(jul_if5) == if5
    @test juliatoWA_wrap(jul_eval1) == eval1
    @test juliatoWA_wrap(jul_eval2) == eval2
    @test juliatoWA(jul_eval3, Env(env_varvar)) == eval3
    @test juliatoWA_wrap(jul_mdef1) == mdef1
    @test juliatoWA_wrap(jul_mdef2) == mdef2
    @test juliatoWA_wrap(jul_mdef3) == mdef3
end

@testset "Complex case tests" begin
    @test juliatoWA_wrap(jul_mdef4) == mdef4
    @test juliatoWA_wrap(jul_mdef5) == mdef5
    @test juliatoWA_wrap(jul_mdef6) == mdef6
end
