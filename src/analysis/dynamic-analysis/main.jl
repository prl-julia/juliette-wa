# Test package with overriden functions
function analyzePkg(pkg :: String)
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkg
    Pkg.activate("package-envs/$(pkg)")
    Pkg.add(pkg)
    Pkg.test(pkg)
end

# Override test method to include the overriden eval and invokeLatest
include("test-override.jl")
using Pkg
ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
analyzePkg(ARGS[1])
