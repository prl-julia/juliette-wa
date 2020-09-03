using JLD
using DataFrames
using Gadfly
using ColorSchemes
using Printf
import Cairo, Fontconfig, Colors

const analysis_result_path = "C:/Users/Ben Chung/Downloads/analysis-results (5).jld"

include("../../analysis/static-analysis/lib/analysis.jl")
data = load(analysis_result_path)
pkgs = data["pkgs"]

# per pkg statistics
df = DataFrame()

for (condition,func) in derivedConditions
	df[!, Symbol(condition)] = []
end

for pkg in pkgs
	push!(df, Dict(condition => if func(pkg.pkgStat) && pkg.interestingFiles > 0 1 else 0 end for (condition,func) in derivedConditions))
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

plotcolor = colorant"#444444"

### usage of basic features
bf_data = reverse([neitherEvalOrIL, onlyEval, onlyIL, ilAndEval])
bf_labels = reverse(["Neither", "Eval", "Invokelatest", "Both"])
bars = layer(x=bf_data, y=bf_labels, color=bf_labels, Geom.bar(orientation=:horizontal))
lbls = layer(x=bf_data, y=bf_labels, label=string.(bf_data), Geom.label(position=:right))

cpalette(p) = get(ColorSchemes.gray, p)
bf = plot(lbls, bars, 
	Scale.x_continuous(format=:plain),
	Scale.color_discrete_manual((cpalette.((0:1/(length(bf_data)-1):1) .* 0.8))...), 
	Theme(key_position = :none, grid_line_width=0mm, plot_padding=[0mm,0mm,0mm,0mm],major_label_font_size=10pt,minor_label_font_size=10pt,minor_label_color=plotcolor,major_label_color=plotcolor),
	Coord.cartesian(xmin=0,xmax=3200),
	Guide.xlabel("Packages"),
	Guide.title(nothing), # "(a) Packages with eval and invokelatest"
	Guide.ylabel(nothing));

# eval usage
eval_data = reverse([interestingEvalNoIL, boringNotTopLevel, multipleTopLevel, singleTopLevel])
eval_labels = reverse(["Non-trivial", "Trivial", "Multiple top-level", "Single top-level"])
eval_bars = layer(x=eval_data, y=eval_labels, color=eval_labels, Geom.bar(orientation=:horizontal))
eval_lbls = layer(x=eval_data, y=eval_labels, label=string.(eval_data), Geom.label(position=:right))
eu = plot(eval_lbls, eval_bars, 
	Scale.x_continuous(format=:plain),
	Scale.color_discrete_manual((cpalette.((0:1/(length(eval_data)-1):1) .* 0.8))...), 
	Theme(key_position = :none, grid_line_width=0mm, plot_padding=[0mm,0mm,0mm,0mm],
		  major_label_font_size=10pt,minor_label_font_size=10pt,minor_label_color=plotcolor,major_label_color=plotcolor),
	Coord.cartesian(xmin=0,xmax=550),
	Guide.xlabel("Packages"),
	Guide.title(nothing), # "(b) Packages with eval usage"
	Guide.ylabel(nothing));

draw(PDF("package_eval_usage_evalusage.pdf", 5inch, 1.5inch), eu)
draw(PDF("package_eval_usage_basic.pdf", 5inch, 1.5inch), bf)

# aggregate chart

add_if_present(d::Dict{T,V}, k::T, v::V) where {T,V} = if haskey(d, k) d[k] += v else d[k] = v end

mergedDefns = merge(+, getfield.(getfield.(pkgs, :pkgStat), :evalArgStat)...)
eval_toplevel = Dict(k.astHead=>v for (k,v) in filter(x->!x[1].context.inFunDef && x[1].context.inQuote, mergedDefns))
eval_infunc = Dict(k.astHead=>v for (k,v) in filter(x->x[1].context.inFunDef && x[1].context.inQuote, mergedDefns))

#eval_toplevel[Symbol("(non-WA) macro")] = eval_toplevel[Symbol("@!WAmacro")]
delete!(eval_toplevel, Symbol("@!WAmacro"))
eval_toplevel = collect(eval_toplevel)

#eval_infunc[Symbol("(non-WA) macro")] = eval_infunc[Symbol("@!WAmacro")]
delete!(eval_infunc, Symbol("@!WAmacro"))
eval_infunc = collect(eval_infunc)

sort!(eval_toplevel, by=x->-x[2])
sort!(eval_infunc, by=x->-x[2])

display_toplevel = Vector{Pair{Symbol,UInt64}}()
append!(display_toplevel, eval_toplevel[1:8])
push!(display_toplevel, :other => sum(getindex.(eval_toplevel[9:end],2)))
display_toplevel = map(kv->string(kv[1])=>kv[2], display_toplevel)
reverse!(display_toplevel)

display_infunc = Vector{Pair{Symbol,UInt64}}()
append!(display_infunc, eval_infunc[1:8])
push!(display_infunc, :other => sum(getindex.(eval_infunc[9:end],2)))
display_infunc = map(kv->string(kv[1])=>kv[2], display_infunc)
reverse!(display_infunc)

#
toplevel_cols = getindex.(display_toplevel, 1)
toplevel_vals = getindex.(display_toplevel, 2)
toplevel_displayvals = convert(Vector{Int}, map(x-> if x > 450 450+(x-450)÷200 else x end, toplevel_vals))
discont = layer(xintercept=[400], Geom.vline(style=:dot,color="grey"))
labels = layer(y=toplevel_cols, x=toplevel_displayvals, label=string.(toplevel_vals), Geom.label(position=:right))
bars = layer(y=toplevel_cols, x=toplevel_displayvals, color=toplevel_cols, Geom.bar(orientation=:horizontal))
toplevel = plot(discont, labels, bars,
	Scale.x_continuous(format=:plain), 
	Coord.cartesian(xmin=0,xmax=550), 
	Scale.color_discrete_manual((cpalette.((0:1/(length(toplevel_cols)-1):1) .* 0.8))...), Theme(key_position = :none, 
		grid_line_width=0mm, plot_padding=[0mm,0mm,0mm,0mm],major_label_font_size=10pt,minor_label_font_size=10pt,minor_label_color=plotcolor,major_label_color=plotcolor),
	Guide.xticks(ticks=0:100:400),
	Guide.yticks(orientation=:horizontal),
	Guide.ylabel(nothing),
	Guide.title(nothing), # "(a) Eval AST forms at top level"
	Guide.xlabel(nothing));

infunc_cols = getindex.(display_infunc, 1)
infunc_vals = convert(Vector{Int}, getindex.(display_infunc, 2))
infunc_displayvals = convert(Vector{Int}, map(x-> if x > 450 450+(x-450)÷200 else x end, infunc_vals))
discont = layer(xintercept=[400], Geom.vline(style=:dot,color="grey"))
labels = layer(y=infunc_cols, x=infunc_displayvals, label=string.(infunc_vals), Geom.label(position=:right))
bars = layer(y=infunc_cols, x=infunc_displayvals, color=infunc_cols, Geom.bar(orientation=:horizontal))
infunc = plot(discont, labels, bars,
	Scale.x_continuous(format=:plain), 
	Coord.cartesian(xmin=0,xmax=550), 
	Scale.color_discrete_manual((cpalette.((0:1/(length(infunc_cols)-1):1) .* 0.8))...), 
	Theme(key_position = :none, grid_line_width=0mm, plot_padding=[0mm,0mm,0mm,0mm],major_label_font_size=10pt,minor_label_font_size=10pt,minor_label_color=plotcolor,major_label_color=plotcolor),
	Guide.xticks(ticks=0:100:400),
	Guide.yticks(orientation=:horizontal),
	Guide.xlabel(nothing),
	Guide.title(nothing), # "(b) Eval AST forms inside functions"
	Guide.ylabel(nothing));

draw(PDF("ast_heads_infunc.pdf", 4inch, 2inch), infunc)
draw(PDF("ast_heads_toplevel.pdf", 4inch, 2inch), toplevel)


# per package AST forms


pkgforms = merge(+, map(d->Dict(k=>if v>0 1 else 0 end for (k,v) in d), getfield.(getfield.(pkgs, :pkgStat), :evalArgStat))...)
pkgforms_toplevel = Dict(k.astHead=>v for (k,v) in filter(x->!x[1].context.inFunDef && x[1].context.inQuote, pkgforms))
pkgforms_infunc = Dict(k.astHead=>v for (k,v) in filter(x->x[1].context.inFunDef && x[1].context.inQuote, pkgforms))

#pkgforms_toplevel[:macrocall] += pkgforms_toplevel[Symbol("@!WAmacro")]
delete!(pkgforms_toplevel, Symbol("@!WAmacro"))
pkgforms_toplevel[:import] = pkgforms_toplevel[:useimport]
pkgforms_infunc[:function] += pkgforms_infunc[:(->)]
delete!(pkgforms_toplevel, :useimport)
delete!(pkgforms_toplevel, :(->))
pkgforms_toplevel = collect(pkgforms_toplevel)

#pkgforms_infunc[:macrocall] += pkgforms_infunc[Symbol("@!WAmacro")]
delete!(pkgforms_infunc, Symbol("@!WAmacro"))
pkgforms_infunc[:import] = pkgforms_infunc[:useimport]
pkgforms_infunc[:function] += pkgforms_infunc[:(->)]
delete!(pkgforms_infunc, :useimport)
delete!(pkgforms_infunc, :(->))
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

toplevel_pkg_cols = getindex.(display_ptoplevel, 1)
toplevel_pkg_vals = getindex.(display_ptoplevel, 2)
toplevel_pkg_displayvals = map(x-> if x > 450 450+(x-450)/200 else x end, toplevel_pkg_vals)
discont = layer(xintercept=[400], Geom.vline(style=:dot,color="grey"))
labels = layer(y=toplevel_pkg_cols, x=toplevel_pkg_displayvals, label=string.(toplevel_pkg_vals), Geom.label(position=:right))
bars = layer(y=toplevel_pkg_cols, x=toplevel_pkg_displayvals, color=toplevel_pkg_cols, Geom.bar(orientation=:horizontal))
toplevel = plot(discont, labels, bars,
	Scale.x_continuous(format=:plain), 
	Coord.cartesian(xmin=0,xmax=550), 
	Scale.color_discrete_manual((cpalette.((0:1/(length(toplevel_pkg_cols)-1):1) .* 0.8))...), Theme(key_position = :none, grid_line_width=0mm, plot_padding=[0mm,0mm,0mm,0mm],major_label_font_size=10pt,minor_label_font_size=10pt,minor_label_color=plotcolor,major_label_color=plotcolor),
	Guide.xticks(ticks=0:100:400),
	Guide.xlabel(nothing),
	Guide.title(nothing), # "(a) Packages with AST form at top level"
	Guide.ylabel("AST form", orientation=:vertical),
	Guide.xlabel("Packages"));

infunc_pkg_cols = getindex.(display_pinfunc, 1)
infunc_pkg_vals = getindex.(display_pinfunc, 2)
infunc_pkg_displayvals = map(x-> if x > 450 450+(x-450)/200 else x end, infunc_pkg_vals)
labels = layer(y=infunc_pkg_cols, x=infunc_pkg_displayvals, label=string.(infunc_pkg_vals), Geom.label(position=:right))
bars = layer(y=infunc_pkg_cols, x=infunc_pkg_displayvals, color=infunc_pkg_cols, Geom.bar(orientation=:horizontal))
infunc = plot(labels, bars,
	Scale.x_continuous(format=:plain),
	Scale.color_discrete_manual((cpalette.((0:1/(length(infunc_pkg_cols)-1):1) .* 0.8))...), Theme(key_position = :none, grid_line_width=0mm, plot_padding=[0mm,0mm,0mm,0mm],major_label_font_size=10pt,minor_label_font_size=10pt,minor_label_color=plotcolor,major_label_color=plotcolor),
	Guide.xticks(ticks=0:20:80),
	Coord.cartesian(xmin=0,xmax=100), 
	Guide.xlabel(nothing),
	Guide.title(nothing), # "(b) Packages with AST form inside function"
	Guide.ylabel(nothing),
	Guide.ylabel("AST form", orientation=:vertical),
	Guide.xlabel("Packages"));
draw(PDF("pkg_heads_toplevel.pdf", 5inch, 2inch), toplevel)
draw(PDF("pkg_heads_infunc.pdf", 5inch, 2inch), infunc)
