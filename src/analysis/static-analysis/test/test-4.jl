module Html


using Revise
import Markdown, Logging, Gumbo, Reexport, OrderedCollections, Millboard, HTTP, YAML

Reexport.@reexport using Genie

import Genie.Renderer
import Genie.Renderer: @vars
Reexport.@reexport using HttpCommon

"""
    include_markdown(path::String; context::Module = @__MODULE__)

Includes and renders a markdown view file
"""
function include_markdown(path::String; context::Module = @__MODULE__)
  content = string("\"\"\"", eval_markdown(read(path, String), context = context), "\"\"\"")
  injected_vars = Genie.Renderer.injectvars()
  injected_vars, (Base.include_string(context, string(injected_vars, content)) |> Markdown.parse |> Markdown.html)
end


"""
    eval_markdown(md::String; context::Module = @__MODULE__) :: String

Converts the mardown `md` to HTML view code.
"""
function eval_markdown(md::String; context::Module = @__MODULE__) :: String
  if startswith(md, string(MD_SEPARATOR_START, "\n")) ||
      startswith(md, string(MD_SEPARATOR_START, "\r")) ||
        startswith(md, string(MD_SEPARATOR_START, "\r\n"))
    close_sep_pos = findfirst(MD_SEPARATOR_END, md[length(MD_SEPARATOR_START)+1:end])
    metadata = md[length(MD_SEPARATOR_START)+1:close_sep_pos[end]] |> YAML.load

    isa(metadata, Dict) || (@warn "\nFound Markdown YAML metadata but it did not result in a `Dict` \nPlease check your markdown metadata \n$metadata")

    try
      for (k,v) in metadata
        task_local_storage(:__vars)[Symbol(k)] = v
      end
    catch ex
      @error ex
    end

    md = replace(md[close_sep_pos[end]+length(MD_SEPARATOR_END)+1:end], "\"\"\""=>"\\\"\\\"\\\"")
  end

  md
end

"""
    html(md::Markdown.MD; context::Module = @__MODULE__, status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders(), layout::Union{String,Nothing} = nothing, forceparse::Bool = false, vars...) :: Genie.Renderer.HTTP.Response

Markdown view rendering
"""
function html(md::Markdown.MD; context::Module = @__MODULE__, status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders(), layout::Union{String,Nothing} = nothing, forceparse::Bool = false, vars...) :: Genie.Renderer.HTTP.Response
  data = eval_markdown(string(md)) |> Markdown.parse |> Markdown.html
  for kv in vars
    data = replace(data, ":" * string(kv[1]) => "\$" * string(kv[1]))
  end

  html(data; context = context, status = status, headers = headers, layout = layout, forceparse = forceparse, vars...)
end


"""
    html(viewfile::FilePath; layout::Union{Nothing,FilePath} = nothing,
          context::Module = @__MODULE__, status::Int = 200, headers::HTTPHeaders = HTTPHeaders(), vars...) :: HTTP.Response

Parses and renders the HTML `viewfile`, optionally rendering it within the `layout` file. Valid file format is `.html.jl`.

# Arguments
- `viewfile::FilePath`: filesystem path to the view file as a `Renderer.FilePath`, ie `Renderer.FilePath("/path/to/file.html.jl")`
- `layout::FilePath`: filesystem path to the layout file as a `Renderer.FilePath`, ie `Renderer.FilePath("/path/to/file.html.jl")`
- `context::Module`: the module in which the variables are evaluated (in order to provide the scope for vars). Usually the controller.
- `status::Int`: status code of the response
- `headers::HTTPHeaders`: HTTP response headers
"""
function html(viewfile::Genie.Renderer.FilePath; layout::Union{Nothing,Genie.Renderer.FilePath} = nothing,
                context::Module = @__MODULE__, status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders(), vars...) :: Genie.Renderer.HTTP.Response
  Genie.Renderer.WebRenderable(Genie.Renderer.render(MIME"text/html", viewfile; layout = layout, context = context, vars...), status, headers) |> Genie.Renderer.respond
end

function parsetags(code::String) :: String
  replace(
    replace(code, "<%"=>"""<script type="julia/eval">"""),
    "%>"=>"""</script>""")
end


"""
    register_elements() :: Nothing

Generated functions that represent Julia functions definitions corresponding to HTML elements.
"""
function register_elements() :: Nothing
  for elem in NORMAL_ELEMENTS
    register_normal_element(elem)
  end

  for elem in VOID_ELEMENTS
    register_void_element(elem)
  end

  for elem in CUSTOM_ELEMENTS
    Core.eval(@__MODULE__, """include("html/$elem.jl")""" |> Meta.parse)
  end

  nothing
end


"""
    register_element(elem::Union{Symbol,String}, elem_type::Union{Symbol,String} = :normal; context = @__MODULE__) :: Nothing

Generates a Julia function representing an HTML element.
"""
function register_element(elem::Union{Symbol,String}, elem_type::Union{Symbol,String} = :normal; context = @__MODULE__) :: Nothing
  elem = string(elem)
  occursin("-", elem) && (elem = denormalize_element(elem))

  elem_type == :normal ? register_normal_element(elem) : register_void_element(elem)
end


"""
    register_normal_element(elem::Union{Symbol,String}; context = @__MODULE__) :: Nothing

Generates a Julia function representing a "normal" HTML element: that is an element with a closing tag, <tag>...</tag>
"""
function register_normal_element(elem::Union{Symbol,String}; context = @__MODULE__) :: Nothing
  Core.eval(context, """
    function $elem(f::Function, args...; attrs...) :: HTMLString
      \"\"\"\$(normal_element(f, "$(string(elem))", [args...], Pair{Symbol,Any}[attrs...]))\"\"\"
    end
  """ |> Meta.parse)

  Core.eval(context, """
    function $elem(children::Union{String,Vector{String}} = "", args...; attrs...) :: HTMLString
      \"\"\"\$(normal_element(children, "$(string(elem))", [args...], Pair{Symbol,Any}[attrs...]))\"\"\"
    end
  """ |> Meta.parse)

  Core.eval(context, """
    function $elem(children::Any, args...; attrs...) :: HTMLString
      \"\"\"\$(normal_element(string(children), "$(string(elem))", [args...], Pair{Symbol,Any}[attrs...]))\"\"\"
    end
  """ |> Meta.parse)

  Core.eval(context, """
    function $elem(children::Vector{Any}, args...; attrs...) :: HTMLString
      \"\"\"\$(normal_element([string(c) for c in children], "$(string(elem))", [args...], Pair{Symbol,Any}[attrs...]))\"\"\"
    end
  """ |> Meta.parse)

  elem in NON_EXPORTED || Core.eval(context, "export $elem" |> Meta.parse)

  nothing
end


"""
    register_void_element(elem::Union{Symbol,String}; context::Module = @__MODULE__) :: Nothing

Generates a Julia function representing a "void" HTML element: that is an element without a closing tag, <tag />
"""
function register_void_element(elem::Union{Symbol,String}; context::Module = @__MODULE__) :: Nothing
  Core.eval(context, """
    function $elem(args...; attrs...) :: HTMLString
      \"\"\"\$(void_element("$(string(elem))", [args...], Pair{Symbol,Any}[attrs...]))\"\"\"
    end
  """ |> Meta.parse)

  elem in NON_EXPORTED || Core.eval(context, "export $elem" |> Meta.parse)

  nothing
end


"""
    @attr(attr)

Returns an HTML attribute string.
"""
macro attr(attr)
  "$(string(attr))"
end


"""
    @foreach(f, arr)

Iterates over the `arr` Array and applies function `f` for each element.
The results of each iteration are concatenated and the final string is returned.

## Examples

@foreach(@vars(:translations)) do t
  t
end
"""
macro foreach(f, arr)
  e = quote
    isempty($(esc(arr))) && return ""

    mapreduce(*, $(esc(arr))) do _s
      $(esc(f))(_s)
    end
  end

  quote
    Core.eval($__module__, $e)
  end
end

end
