
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
floatpi = WANumber(3.14)
strabc = WAString("abc")
btrue = WABoolean(true)
bfalse = WABoolean(false)
varx = WAVariable(:x)
varvar = WAVariable(:var)
noth = WANothing()
mvalf = WAVariable(:f)
mvalcomp = WAVariable(:compose)

seq1 = WASequence(int1, btrue)
seq2 = WASequence(varx, seq1)

call1 = WACall(mvalf, [WANumber(-1)])
call2 = WACall(mvalcomp, [])
call3 = WACall(btrue, [noth, btrue])
call4 = WAPrimopCall(:+, [int1, floatpi])
call5 = WAPrimopCall(:print, [strabc])
call6 = WAPrimopCall(:*, [int1, floatpi])
call7 = WAPrimopCall(:/, [int1, floatpi])
call8 = WAPrimopCall(:-, [int1, floatpi])
call12 = WAPrimopCall(:&&, [btrue, bfalse])
call13 = WAPrimopCall(:||, [bfalse, bfalse])
call14 = WAPrimopCall(:!, [btrue])
call15 = WAPrimopCall(Symbol("@assert"), [WAPrimopCall(:(==), [WANumber(1), WANumber(2)])])
if1 = WAIfThenElse(call14, int1, call1)

eval1 = WAGlobalEval(strabc)
eval2 = WAGlobalEval(eval1)

mdef1 = WAMethodDef(:f, [], eval2)
mdef2 = WAMethodDef(:g, [(:x,anytype), (:y,inttype)], mdef1)

#########
# Tests #
#########

using Test

@testset "Unparser tests" begin
    @test unparser(int1) == "(term 1)"
    @test unparser(floatpi) == "(term 3.14)"
    @test unparser(strabc) == "(term \"abc\")"
    @test unparser(btrue) == "(term true)"
    @test unparser(bfalse) == "(term false)"
    @test unparser(varx) == "(term x)"
    @test unparser(varvar) == "(term var)"
    @test unparser(noth) == "(term nothing)"
    @test unparser(seq1) == "(term (seq 1 true))"
    @test unparser(seq2) == "(term (seq x (seq 1 true)))"
    @test unparser(call1) == "(term (mcall f -1))"
    @test unparser(call2) == "(term (mcall compose))"
    @test unparser(call3) == "(term (mcall true nothing true))"
    @test unparser(call4) == "(term (pcall + 1 3.14))"
    @test unparser(call5) == "(term (pcall print \"abc\"))"
    @test unparser(call6) == "(term (pcall * 1 3.14))"
    @test unparser(call7) == "(term (pcall / 1 3.14))"
    @test unparser(call8) == "(term (pcall - 1 3.14))"
    @test unparser(call12) == "(term (pcall && true false))"
    @test unparser(call13) == "(term (pcall || false false))"
    @test unparser(call14) == "(term (pcall ! true))"
    @test unparser(call15) == "(term (pcall @assert (pcall == 1 2)))"
    @test unparser(if1) == "(term (if (pcall ! true) 1 (mcall f -1)))"
    @test unparser(eval1) == "(term (evalg \"abc\"))"
    @test unparser(eval2) == "(term (evalg (evalg \"abc\")))"
    @test unparser(mdef1) == "(term (mdef \"f\" () (evalg (evalg \"abc\"))))"
    @test unparser(mdef2) == "(term (mdef \"g\" ((:: x Any) (:: y Int64)) (mdef \"f\" () (evalg (evalg \"abc\")))))"
end
