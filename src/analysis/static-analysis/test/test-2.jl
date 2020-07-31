## First pass at math functions. There are more domain restrictions to be implemented.

### SetPrecision

"""
    evalmath(expr::Expr)

Evaluate `expr`. This is used for writing Symata interfaces
to math functions. Currently, it is equivalent to `eval`.
"""
evalmath(expr::Expr) = Symata.eval(expr::Expr)

const no_julia_function_four_args = [ (:JacobiP, :jacobi), (:SphericalHarmonicY, :Ynm) ]

function make_math()

# Note: in Mma and Julia, catalan and Catalan are Catalan's constant. In sympy catalan is the catalan number
# can't find :stirling in sympy

    for x in no_julia_function_one_arg
        sjf = x[1]
        eval(macroexpand(Symata, :( @mkapprule $sjf)))
        write_sympy_apprule(x[1],x[2],1)
    end


    for x in no_julia_function_two_args
        sjf = x[1]
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 2)))
        write_sympy_apprule(x[1],x[2],2)
    end

    for x in no_julia_function_four_args
        nargs = 4
        sjf = x[1]
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => $nargs)))
        write_sympy_apprule(x[1],x[2],nargs)
    end

    for x in no_julia_function_three_args
        nargs = 3
        sjf = x[1]
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => $nargs)))
        write_sympy_apprule(x[1],x[2],nargs)
    end

    for x in no_julia_function_two_or_three_args
        sjf = x[1]
        eval(macroexpand(Symata, :( @mkapprule $sjf)))
        write_sympy_apprule(x[1],x[2],2)
        write_sympy_apprule(x[1],x[2],3)
    end


    for x in no_julia_function_one_or_two_int
        sjf = x[1]
        eval(macroexpand(Symata, :( @mkapprule $sjf)))
        write_sympy_apprule(x[1],x[2],1)
        write_sympy_apprule(x[1],x[2],2)
    end

    # TODO: update this code
    for x in no_julia_function
        set_up_sympy_default(x...)
        clear_attributes(x[1]) ## FIXME: Listable was set in previous line. Now we unset it. We need a better system for this.
        set_sysattributes(x[1])
    end

    # Ok, this works. We need to clean it up
    for x in single_arg_float_complex
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 1 )))
        write_julia_numeric_rule(jf,sjf,"AbstractFloat")
        write_julia_numeric_rule(jf,sjf,"CAbstractFloat")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],1)
        end
        set_attribute(Symbol(sjf),:Listable)
    end

    for x in single_arg_float
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 1 )))
        write_julia_numeric_rule(jf,sjf,"AbstractFloat")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],1)
        end
        set_attribute(Symbol(sjf),:Listable)
    end

    for x in single_arg_float_int
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 1 )))
        write_julia_numeric_rule(jf,sjf,"Real")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],1)
        end
    end

    # This is all numbers, I suppose
    for x in single_arg_float_int_complex
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 1 )))
        write_julia_numeric_rule(jf,sjf,"Real")
        write_julia_numeric_rule(jf,sjf,"CReal")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],1)
        end
    end

    for x in single_arg_int
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 1 :argtypes => [Integer] )))
        write_julia_numeric_rule(jf,sjf,"Integer")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],1)
        end
    end

    for x in two_arg_int
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 2 )))
        write_julia_numeric_rule(jf,sjf,"Integer", "Integer")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],2)
        end
    end

    # Mma allows one arg, as well
    for x in one_or_two_args1
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf )))
        write_julia_numeric_rule(jf,sjf,"Integer", "AbstractFloat")
        write_julia_numeric_rule(jf,sjf,"Integer", "CAbstractFloat")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],2)
        end
    end

    for x in two_arg_float
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 2 )))
        write_julia_numeric_rule(jf,sjf,"AbstractFloat", "AbstractFloat")
    end

    for x in two_arg_float_and_float_or_complex
        jf,sjf = only_get_sjstr(x...)
        eval(macroexpand(Symata, :( @mkapprule $sjf :nargs => 2 )))
        write_julia_numeric_rule(jf,sjf,"AbstractFloat", "AbstractFloat")
        write_julia_numeric_rule(jf,sjf,"AbstractFloat", "CAbstractFloat")
        write_julia_numeric_rule(jf,sjf,"Integer", "AbstractFloat")
        write_julia_numeric_rule(jf,sjf,"Integer", "CAbstractFloat")
        if length(x) == 3
            write_sympy_apprule(sjf,x[3],2)
        end
    end
end

Typei(i::Int)  =  "T" *string(i)
complex_type(t::AbstractString) = "Complex{" * t * "}"
function write_julia_numeric_rule(jf, sjf, types...)
    annot = join(AbstractString[ "T" * string(i) * "<:" *
                                 (types[i][1] == 'C' ? types[i][2:end] : types[i])  for i in 1:length(types)], ", ")
    protargs = join(AbstractString[ "x" * string(i) * "::" *
                                (types[i][1] == 'C' ? complex_type(Typei(i)) : Typei(i))
                                    for i in 1:length(types)], ", ")
    callargs = join(AbstractString[ "x" * string(i) for i in 1:length(types)], ", ")
#    appstr = "do_$sjf{$annot}(mx::Mxpr{:$sjf},$protargs) = $jf($callargs)"
    appstr = "do_$sjf(mx::Mxpr{:$sjf},$protargs) where {$annot} = $jf($callargs)"
    eval(Meta.parse(appstr))
end

function only_get_sjstr(jf,sjf,args...)
    return jf, sjf
end

## FIXME: This is outdated. Some of this is handled in @mkapprule
# Handle functions that do *not* fall back on SymPy
function do_common(sjf)
    aprs = "Symata.apprules(mx::Mxpr{:$sjf}) = do_$sjf(mx,margs(mx)...)"
    aprs1 = "do_$sjf(mx::Mxpr{:$sjf},x...) = mx"
    evalmath(Meta.parse(aprs))
    evalmath(Meta.parse(aprs1))
    set_attribute(Symbol(sjf),:Protected)
    set_attribute(Symbol(sjf),:Listable)
end

# Faster if we don't do interpolation
function write_sympy_apprule(sjf, sympyf, nargs::Int)
    callargs = Array{AbstractString}(undef, 0)
    sympyargs = Array{AbstractString}(undef, 0)
    for i in 1:nargs
        xi = "x" * string(i)
        push!(callargs, xi)
        push!(sympyargs, "sjtopy(" * xi * ")")
        end
    cstr = join(callargs, ", ")
    sstr = join(sympyargs, ", ")
    aprpy = "function do_$sjf(mx::Mxpr{:$sjf},$cstr)
               try
                 (sympy.$sympyf($sstr) |> pytosj)
               catch e
                 showerror(stdout, e)
                 mx
               end
            end"
    evalmath(Meta.parse(aprpy))
end


function set_up_sympy_default(sjf, sympyf)
    aprs = "Symata.apprules(mx::Mxpr{:$sjf}) = do_$sjf(mx,margs(mx)...)"
    aprs1 = "function do_$sjf(mx::Mxpr{:$sjf},x...)
               try
                 (sympy.$sympyf(map(sjtopy,x)...) |> pytosj)
               catch
                   mx
               end
           end"
    evalmath(Meta.parse(aprs))
    evalmath(Meta.parse(aprs1))
    set_attribute(Symbol(sjf),:Protected)
    set_attribute(Symbol(sjf),:Listable)
end

### N

@sjdoc N """
    N(expr)

try to give a the numerical value of `expr`.

    N(expr,p)

try to give `p` decimal digits of precision.

Sometimes `N` does not give the number of digits requested. In this case, you can use `SetPrecision`.
"""

## TODO: call evalf(expr,n) on sympy functions to get arbitrary precision numbers.
## Eg. N(LogIntegral(4),30) does not give correct result.
## ... a list of heads all of which should be converted and then passed to evalf.
## N needs to be rewritten
function apprules(mx::Mxpr{:N})
    outer_N(margs(mx)...)
end

function outer_N(expr)
    do_N(expr)
end

function outer_N(expr, p)
    if p > 16
        pr = precision(BigFloat)
        dig = round(Int,p*3.322)
        set_mpmath_dps(dig)     # This is for some SymPy math. But, it is not clear when this will help us
        setprecision( BigFloat, dig) # new form
        res = meval(do_N(expr,p))
        setprecision(BigFloat, pr)
        restore_mpmath_dps()
        return res
    else
        do_N(expr)
    end
end

function make_Mxpr_N()
    _Nbody = _make_N_body(:(do_N(args[1])), :(do_N(args[i])) )
    @eval begin
        function do_N(mx::Mxpr)
            $_Nbody
            res
        end
    end

    _Nbody = _make_N_body(:(do_N(args[1],p)), :(do_N(args[i],p)) )
    @eval begin
        function do_N(mx::Mxpr,p::T) where T<:Integer
            $_Nbody
            res
        end
    end
end

make_Mxpr_N()

@mkapprule Rationalize
do_Rationalize(mx::Mxpr{:Rationalize},x::AbstractFloat) = rationalize(x)
do_Rationalize(mx::Mxpr{:Rationalize},x::AbstractFloat,tol::Number) = rationalize(x,tol=float(tol))
function do_Rationalize(mx::Mxpr{:Rationalize},x::Symbolic)
    r = doeval(mxpr(:N,x))  # we need to redesign do_N so that we can call it directly. See above
    return isa(r,AbstractFloat) ? do_Rationalize(mx,r) : x
end
function do_Rationalize(mx::Mxpr{:Rationalize},x::Symbolic,tol::Number)
    ndig = round(Int,-log10(tol))      # This is not quite correct.
    r = doeval(mxpr(:N,x,ndig))  # we need to redesign do_N so that we can call it directly. See above.
    return isa(r,AbstractFloat) ? do_Rationalize(mx,r,tol) : x
end
do_Rationalize(mx::Mxpr{:Rationalize},x) = x

### ExpPolar

## sympy returns this sometimes. I am not sure what it is, but it usually just hinders
## desired evaluation. We could also handle this as a direct translation in sympy.jl.
## There may be some reason to preserve this.

