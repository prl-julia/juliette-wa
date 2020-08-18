include("test-override.jl")
using Pkg

# Test package with overriden functions
function analyzePkg(pkgName :: String, pkgVersion :: Union{String, Nothing})
    ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkgName
    ENV["OUTPUT_DIR"] = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"])"
    # DEPOT_PATH[1] = "$(ENV["OUTPUT_DIR"])/env"
    try mkdir(ENV["OUTPUT_DIR"]) catch e end
    # try mkdir(DEPOT_PATH[1]) catch e end
    pkg = pkgVersion == nothing ? pkgName : Pkg.PackageSpec(;name=pkgName, version=pkgVersion)
    Pkg.add(pkg)
    Pkg.test(pkg)
end

analyzePkg(ARGS[1], length(ARGS) == 2 ? ARGS[2] : nothing)
