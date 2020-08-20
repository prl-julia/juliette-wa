using Pkg

const UNIQUE_LINE_ID = "### DYNAMIC ANALYSIS LINE IDENTIFIER ###"

addUniqueLineIdentifier() = (println(UNIQUE_LINE_ID); println(stderr, UNIQUE_LINE_ID))

getPkg(pkgName :: String, pkgVersion :: Union{String, Nothing}) =
    pkgVersion == nothing ? pkgName : Pkg.PackageSpec(;name=pkgName, version=pkgVersion)

getPkgVersionFromArgs() = length(ARGS) == 2 ? ARGS[2] : nothing
