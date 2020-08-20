include("test-override.jl")
include("utils.jl")
using Pkg

# Test package with overriden functions
function analyzePkg(pkgName :: String, pkgVersion :: Union{String, Nothing})
    pkg = getPkg(pkgName, pkgVersion)
    Pkg.add(pkg)
    ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkgName
    ENV["OUTPUT_DIR"] = "$(ENV["DYNAMIC_ANALYSIS_DIR"])/package-data/$(pkgName)-$(Pkg.installed()[pkgName])"
    addUniqueLineIdentifier()
    Pkg.test(pkg)
end

analyzePkg(ARGS[1], getPkgVersionFromArgs())
