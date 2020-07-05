###############
# Environment #
###############

# Represents an item that can stored in the scope
abstract type ScopeComponent end
# Represents the separation of scope locality. This is needed to differentiate
# between interpolated variables
struct ScopeSeparator <: ScopeComponent end
# Represents a variable that exists in the scope. The source name is the name of
# the variable in the source language of translation, while the target name is
# the name in the target language
struct LocalVar <: ScopeComponent
    source_varname :: Symbol
    target_varname :: Symbol
end

# Represents the accumlation of scope and name mappings at a given point in a
# program. The local scope is the stack of all loval variables in scope for an
# expression.
struct Env
    localscope :: ImmutableStack{ScopeComponent}
end
Env() = Env(EmptyStack{ScopeComponent}())

#########################
# Environment Interface #
#########################

# has_source_varname: returns true if the ScopeComponent has the given
# source_varname as its own source_varname, false otherwise
has_source_varname(separator :: ScopeComponent, source_varname :: Symbol) = false
has_source_varname(var :: LocalVar,             source_varname :: Symbol) = 
    var.source_varname == source_varname

# has_target_varname: returns true if the ScopeComponent has the given
# target_varname as its own target_varname, false otherwise
has_target_varname(separator :: ScopeComponent, target_varname :: Symbol) = false
has_target_varname(var :: LocalVar,             target_varname :: Symbol) = 
    var.target_varname == target_varname

# addseparator: creates a new Environment with a ScopeSeparator pushed onto the
# localscope of the given environment
addseparator(env :: Env) :: Env = Env(push(ScopeSeparator(), env.localscope))

# addlocalvar: creates a new Environment with a mapping of the given source
# variable name to a generated target variable name pushed onto the localscope
# of the given environment. Returns the new env as well as the generated target
# varname
function addlocalvar(env :: Env, source_varname :: Symbol) :: Tuple{Symbol,Env}
    target_varname = generate_name(env, source_varname)
    updatedscope = push(LocalVar(source_varname, target_varname), env.localscope)
    (target_varname, Env(updatedscope))
end

# get_target_varname: gets the target variable name mapped to the given
# src_var. Returns nothing if not found. Note the interp_cnt is
# number of separators that are between the current local scope and the variable to be found
function get_target_varname(env :: Env, src_var :: Symbol, 
                            interp_cnt :: Int64) :: Union{Symbol,Nothing}
    foundvar(component :: ScopeSeparator) :: Bool = 
        (interp_cnt -= 1; false)             
    foundvar(component :: ScopeComponent) :: Bool =
        interp_cnt == 0 && has_source_varname(component, src_var)
    
    matchedvar = findfirst(foundvar, env.localscope)
    matchedvar != nothing ? matchedvar.target_varname : nothing
end

# generate_name: generates a variable name for the target langugae that does not
# yet exist in the given environment
function generate_name(env :: Env, varname :: Symbol) :: Symbol
    i = 1
    while true
        generated_name = Symbol(i, "_", varname)
        if !contains(env, generated_name) && !isa_primop(generated_name)
            return generated_name
        end
        i += 1
    end
end

# contains: returns true if the given name is already a target name in the given
# environment, false otherwise
function contains(env :: Env, varname :: Symbol) :: Bool
    same_target_varname = (component :: ScopeComponent) -> has_target_varname(component, varname)
    findfirst(same_target_varname, env.localscope) != nothing
end

# isa_primop: returns true if this callee is considered a primitive opration in
# the world-age language
isa_primop(name :: Symbol) :: Bool = findlast(isequal(name), PRIMOPS) != nothing
isa_primop(name)           :: Bool = false
