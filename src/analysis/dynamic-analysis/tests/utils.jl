#################
# Test Helpers
#################

macro parse(ast)
    return :(Meta.parse($ast))
end
