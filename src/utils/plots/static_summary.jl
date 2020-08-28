using JLD
using DataFrames
using Gadfly
using ColorSchemes
using Printf
import Cairo, Fontconfig

const analysis_result_path = "C:/Users/Ben Chung/Downloads/analysis-results (2).jld"

include("../../analysis/static-analysis/lib/analysis.jl")
data = load(analysis_result_path)
pkgs = data["pkgs"]

# per pkg statistics
df = DataFrame()

for (condition,func) in derivedConditions
	df[!, Symbol(condition)] = []
end

for pkg in pkgs
	push!(df, Dict(condition => reduce(+, [if func(stat) 1 else 0 end for (_,stat) in pkg.filesStat], init=0) for (condition,func) in derivedConditions))
end

dfbool = df[!,:] .> 0
chartdat = Dict(condition=>sum(dfbool[!,condition]) for (condition,func) in derivedConditions)

neitherEvalOrIL = length(pkgs) - chartdat["hasOnlyEval"] - chartdat["hasOnlyIL"] - chartdat["hasBothEvalIL"]
onlyEval = chartdat["hasOnlyEval"]
onlyIL = chartdat["hasOnlyIL"]
ilAndEval = chartdat["hasBothEvalIL"]

interestingEvalNoIL = chartdat["hasOnlyEval"] - chartdat["allEvalBoringNoIL"]
boringNotTopLevel = chartdat["allEvalBoringNoIL"] - chartdat["allEvalTopNoIL"]
multipleTopLevel = chartdat["allEvalTopNoIL"] - chartdat["1TopEvalNoIL"]
singleTopLevel = chartdat["1TopEvalNoIL"]

nIL = chartdat["il"]
nEval = chartdat["hasEval"]

### usage of basic features
bf_data = [neitherEvalOrIL, onlyEval, onlyIL, ilAndEval]
bf_labels = ["Neither", "Only eval", "Only invokelatest", "Both"]
bars = layer(y=bf_data, x=bf_labels, color=bf_labels, Geom.bar)
lbls = layer(y=bf_data, x=bf_labels, label=string.(bf_data), Geom.label(position=:above))

cpalette(p) = get(ColorSchemes.gray, p)
bf = plot(lbls, bars, 
	Scale.y_continuous(format=:plain),
	Scale.color_discrete_manual((cpalette.((0:1/(length(bf_data)-1):1) .* 0.8))...), Theme(key_position = :none),
	Coord.cartesian(ymin=0,ymax=3200),
	Guide.xlabel(nothing),
	Guide.title("(a) Eval and invokelatest usage by package"),
	Guide.ylabel("Packages"));

# eval usage
eval_data = [interestingEvalNoIL, boringNotTopLevel, multipleTopLevel, singleTopLevel]
eval_labels = ["Non-trivial", "Non-top-level trivial", "Multiple top-level", "Single top-level"]
eval_bars = layer(y=eval_data, x=eval_labels, color=eval_labels, Geom.bar)
eval_lbls = layer(y=eval_data, x=eval_labels, label=string.(eval_data), Geom.label(position=:above))
eu = plot(eval_lbls, eval_bars, 
	Scale.y_continuous(format=:plain),
	Scale.color_discrete_manual((cpalette.((0:1/(length(eval_data)-1):1) .* 0.8))...), Theme(key_position = :none),
	Coord.cartesian(ymin=0,ymax=600),
	Guide.xlabel(nothing),
	Guide.title("(b) Eval AST type by package"),
	Guide.ylabel("Packages"));

# aggregate chart
draw(PDF("package_eval_usage.pdf", 6inch, 8inch), vstack(bf, eu))

add_if_present(d::Dict{T,V}, k::T, v::V) where {T,V} = if haskey(d, k) d[k] += v else d[k] = v end

mergedDefns = merge(+, getfield.(getfield.(pkgs, :pkgStat), :evalArgStat)...)
eval_toplevel = Dict(k.astHead=>v for (k,v) in filter(x->!x[1].inFunDef, mergedDefns))
eval_infunc = Dict(k.astHead=>v for (k,v) in filter(x->x[1].inFunDef, mergedDefns))

missing_to_z(v) = if ismissing(v) 0 else v end
eval_toplevel[:macrocall] += eval_toplevel[Symbol("@!WAmacro")]
delete!(eval_toplevel, Symbol("@!WAmacro"))
eval_toplevel = collect(eval_toplevel)

eval_infunc[:macrocall] += eval_infunc[Symbol("@!WAmacro")]
delete!(eval_infunc, Symbol("@!WAmacro"))
eval_infunc = collect(eval_infunc)

sort!(eval_toplevel, by=x->-x[2])
sort!(eval_infunc, by=x->-x[2])

display_toplevel = Vector{Pair{Symbol,UInt64}}()
append!(display_toplevel, eval_toplevel[1:8])
push!(display_toplevel, :other => sum(getindex.(eval_toplevel[9:end],2)))
display_toplevel = map(kv->string(kv[1])=>kv[2], display_toplevel)

display_infunc = Vector{Pair{Symbol,UInt64}}()
append!(display_infunc, eval_infunc[1:8])
push!(display_infunc, :other => sum(getindex.(eval_infunc[9:end],2)))
display_infunc = map(kv->string(kv[1])=>kv[2], display_infunc)

#
toplevel_cols = getindex.(display_toplevel, 1)
toplevel_vals = getindex.(display_toplevel, 2)
toplevel_displayvals = map(x-> if x > 1250 1250+(x-1250)/30 else x end, toplevel_vals)
discont = layer(yintercept=[1000], Geom.hline(style=:dot,color="grey"))
labels = layer(x=toplevel_cols, y=toplevel_displayvals, label=string.(toplevel_vals), Geom.label(position=:above))
bars = layer(x=toplevel_cols, y=toplevel_displayvals, color=toplevel_cols, Geom.bar())
toplevel = plot(discont, labels, bars,
	Scale.y_continuous(format=:plain), 
	Coord.cartesian(ymin=0,ymax=1600), 
	Scale.color_discrete_manual((cpalette.((0:1/(length(toplevel_cols)-1):1) .* 0.8))...), Theme(key_position = :none),
	Guide.yticks(ticks=0:200:1000),
	Guide.xticks(orientation=:vertical),
	Guide.xlabel(nothing),
	Guide.title("(a) Eval AST heads at top level"),
	Guide.ylabel("AST heads"));

infunc_cols = getindex.(display_infunc, 1)
infunc_vals = getindex.(display_infunc, 2)
infunc_displayvals = map(x-> if x > 1250 1250+(x-1250)/30 else x end, infunc_vals)
discont = layer(yintercept=[1000], Geom.hline(style=:dot,color="grey"))
labels = layer(x=infunc_cols, y=infunc_displayvals, label=string.(infunc_vals), Geom.label(position=:above))
bars = layer(x=infunc_cols, y=infunc_displayvals, color=infunc_cols, Geom.bar())
infunc = plot(discont, labels, bars,
	Scale.y_continuous(format=:plain), 
	Coord.cartesian(ymin=0,ymax=1600), 
	Scale.color_discrete_manual((cpalette.((0:1/(length(infunc_cols)-1):1) .* 0.8))...), Theme(key_position = :none),
	Guide.yticks(ticks=0:200:1000),
	Guide.xticks(orientation=:vertical),
	Guide.xlabel(nothing),
	Guide.title("(b) Eval AST heads inside functions"),
	Guide.ylabel(nothing));

draw(PDF("ast_heads.pdf", 10inch, 4inch), hstack(toplevel, infunc))


# per package AST forms


pkgforms = merge(+, map(d->Dict(k=>if v>0 1 else 0 end for (k,v) in d), getfield.(getfield.(pkgs, :pkgStat), :evalArgStat))...)
pkgforms_toplevel = Dict(k.astHead=>v for (k,v) in filter(x->!x[1].inFunDef, pkgforms))
pkgforms_infunc = Dict(k.astHead=>v for (k,v) in filter(x->x[1].inFunDef, pkgforms))

pkgforms_toplevel[:macrocall] += pkgforms_toplevel[Symbol("@!WAmacro")]
delete!(pkgforms_toplevel, Symbol("@!WAmacro"))
pkgforms_toplevel = collect(pkgforms_toplevel)

pkgforms_infunc[:macrocall] += pkgforms_infunc[Symbol("@!WAmacro")]
delete!(pkgforms_infunc, Symbol("@!WAmacro"))
pkgforms_infunc = collect(pkgforms_infunc)

sort!(pkgforms_toplevel, by=x->-x[2])
sort!(pkgforms_infunc, by=x->-x[2])

display_ptoplevel = Vector{Pair{Symbol,UInt64}}()
append!(display_ptoplevel, pkgforms_toplevel[1:8])
push!(display_ptoplevel, :other => sum(getindex.(pkgforms_toplevel[9:end],2)))
display_ptoplevel = map(kv->string(kv[1])=>kv[2], display_ptoplevel)

display_pinfunc = Vector{Pair{Symbol,UInt64}}()
append!(display_pinfunc, pkgforms_infunc[1:8])
push!(display_pinfunc, :other => sum(getindex.(pkgforms_infunc[9:end],2)))
display_pinfunc = map(kv->string(kv[1])=>kv[2], display_pinfunc)