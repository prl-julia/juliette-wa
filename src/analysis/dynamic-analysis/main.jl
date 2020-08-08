include("utils.jl")

# Test package with overriden functions
function analyzePkg(pkg :: String)
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkg
    Pkg.add(pkg)
    # Get names of source files to know what is source code during data analysis
    collectSourceFilenames(pkg)
    Pkg.test(pkg)
end

# Include overrided tester
include("test-override.jl")
using Pkg
# Get Current directory for refererence when writing to files
ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
# Run the given package with the overriden functions
analyzePkg(ARGS[1])
