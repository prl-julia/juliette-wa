include("test-override.jl")
using Pkg

# Test package with overriden functions
function analyzePkg(pkg :: String)
    ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkg
    ENV["OUTPUT_DIR"] = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])"
    DEPOT_PATH[1] = "$(ENV["OUTPUT_DIR"])/env"
    try mkdir(ENV["OUTPUT_DIR"]) catch e end
    try mkdir(DEPOT_PATH[1]) catch e end
    Pkg.add(pkg)
    Pkg.test(pkg)
end

analyzePkg(ARGS[1])
