include("utils.jl")
using Pkg

function testPkg(pkgName :: String, pkgVersion :: Union{String, Nothing})
    pkg = getPkg(pkgName, pkgVersion)
    Pkg.add(pkg)
    addUniqueLineIdentifier()
    Pkg.test(pkg)
end

testPkg(ARGS[1], getPkgVersionFromArgs())
