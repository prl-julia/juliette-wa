
##############################
# Immutable Stack Definition #
##############################

# Represents a stack (last in, first out) data structure that is immutable
abstract type ImmutableStack{T} end
# Represents an empty stack
struct EmptyStack{T} <: ImmutableStack{T} end
# Represents a non-empty stack
struct NonEmptyStack{T} <: ImmutableStack{T}
    top :: T
    rest :: ImmutableStack{T}
end

#############################
# Immutable Stack Interface #
#############################

# push: creates a new stack such that the given item is pushed onto the
# top of the given stack
function push(item :: T, stack :: ImmutableStack{T}) :: ImmutableStack{T} where {T}
    NonEmptyStack(item, stack)
end

# pop: returns the first item of the given stack and the rest of the stack
# without its first item
function pop(stack :: NonEmptyStack{T}) :: Tuple{T,ImmutableStack{T}} where {T}
    (stack.top, stack.rest)
end
function pop(stack :: EmptyStack{T})    :: Tuple{T,ImmutableStack{T}} where {T}
    throw(InvalidStateException("Cannot pop from an empty stack", :pop))
end

# isempty: true if the stack is empty, false otherwise
Base.isempty(stack :: NonEmptyStack) :: Bool = false
Base.isempty(stack :: EmptyStack)    :: Bool = true

# findFirst: returns the first item in the stack such that the predicate is
# true, returns nothing otherwise. Note the predicate is a (item :: T) -> Bool
function findfirst(predicate, stack :: EmptyStack{T}) :: Union{T,Nothing} where {T}
    nothing
end
function findfirst(predicate, stack :: NonEmptyStack{T}) :: Union{T,Nothing} where {T}
    top, rest = pop(stack)
    predicate(top) ?
      top :
      findfirst(predicate, rest)
end
