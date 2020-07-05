
##################
# Julia Programs #
##################

jul_program1 = "
function sub1(x :: Float64)
    x + -1
end
add12(y) = y + 12
function compose(f :: typeof(sub1), g)
    function h(x :: Number)
        return f(g(x))
    end
    eval(:(1 + 2))
    h
end
add11(x :: Int64) = compose(add12, sub1)
add11(600.3)"

jul_program2 = "
function all(a::Number,b::Int64,c::Float64,d::Bool, e::String,
            f::Union{},g::Nothing,h::Any,i::typeof(method))
    begin
        (Base.invokelatest(a,b,c,d);eval(:(g(\$h, \$i))))
    end
end
print(all(1) + nothing)"

jul_program3 = "eval(:(Base.invokelatest(eval(:(begin end)),eval(:((f(x)=:(w(x,y)=eval(:(\$\$x+\$y)));f(1)))))))"

##################
# Redex Programs #
##################

sub1def = "(mdef \"sub1\" ((:: 1_x Float64)) (pcall + 1_x -1))"
add12def = "(mdef \"add12\" ((:: 1_y Any)) (pcall + 1_y 12))"
hdef = "(mdef \"h\" ((:: 1_x Number)) (mcall 1_f (mcall 1_g 1_x)))"
composedef = "(mdef \"compose\" ((:: 1_f (mtag \"sub1\")) (:: 1_g Any)) (seq $(hdef) (seq (evalg (pcall + 1 2)) h)))"
add11def = "(mdef \"add11\" ((:: 1_x Int64)) (mcall compose add12 sub1))"
add11call = "(mcall add11 600.3)"
program1 = "(term (evalg (seq $(sub1def) (seq $(add12def) (seq $(composedef) (seq $(add11def) $(add11call)))))))"

a = "(:: 1_a Number)"
b = "(:: 1_b Int64)"
c = "(:: 1_c Float64)"
d = "(:: 1_d Bool)"
e = "(:: 1_e String)"
f = "(:: 1_f Bot)"
g = "(:: 1_g Nothing)"
h = "(:: 1_h Any)"
i = "(:: 1_i (mtag \"method\"))"
paramdefs = "($(a) $(b) $(c) $(d) $(e) $(f) $(g) $(h) $(i))"
gcall = "(mcall g 1_h 1_i)"
allbody = "(seq (evalg (mcall 1_a 1_b 1_c 1_d)) (evalg $(gcall)))"
allcall = "(mcall all 1)"
printcall = "(pcall print (pcall + $(allcall) nothing))"
program2 = "(term (evalg (seq (mdef \"all\" $(paramdefs) $(allbody)) $(printcall))))"

wdef = "(mdef \"w\" ((:: 2_x Any) (:: 1_y Any)) (evalg (pcall + 1_x 1_y)))"
fdef = "(mdef \"f\" ((:: 1_x Any)) $(wdef))"
fcall = "(mcall f 1)"
program3 = "(term (evalg (evalg (evalg (mcall (evalg nothing) (evalg (seq $(fdef) $(fcall))))))))"

#########
# Tests #
#########

using Test

@testset "Integration tests" begin
    @test transpile(jul_program1) == program1
    @test transpile(jul_program2) == program2
    @test transpile(jul_program3) == program3
end
