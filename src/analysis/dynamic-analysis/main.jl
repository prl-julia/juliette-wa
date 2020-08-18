include("test-override.jl")
using Pkg

# Test package with overriden functions
function analyzePkg(pkgName :: String, pkgVersion :: Union{String, Nothing})
    pkg = pkgVersion == nothing ? pkgName : Pkg.PackageSpec(;name=pkgName, version=pkgVersion)
    Pkg.add(pkg)
    ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkgName
    ENV["OUTPUT_DIR"] = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(pkgName)-$(Pkg.installed()[pkgName])"
    try mkdir(ENV["OUTPUT_DIR"]) catch e end
    Pkg.test(pkg)
end

analyzePkg(ARGS[1], length(ARGS) == 2 ? ARGS[2] : nothing)
