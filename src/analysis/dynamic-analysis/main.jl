include("test-override.jl")
using Pkg

# Test package with overriden functions
function analyzePkg(pkg :: String)
    ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkg
    Pkg.add(pkg)
    Pkg.test(pkg)
end

analyzePkg(ARGS[1])
