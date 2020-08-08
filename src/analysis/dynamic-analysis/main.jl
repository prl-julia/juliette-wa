include("../../jl-transpiler/auxiliary/utils.jl")

# Gets the directory path of the given package
function getPkgSrcDir(pkg :: String)
    for (root, dirs, files) in walkdir(joinpath(DEPOT_PATH[1], "packages", pkg))
        srcDirIndex = findfirst(isequal("src"), dirs)
        srcDirIndex != nothing && return joinpath(root, dirs[srcDirIndex])
    end
end

# Write the names of all the files in the given package to source-filenames.txt
function collectSourceFilenames(pkg :: String)
    pkgSrcDir = getPkgSrcDir(pkg)
    io = open("source-filenames.txt", "w+")
    map(dir ->
        map(fn -> write(io, "$(fn)\n"),
            filter(fn -> endswith(fn, ".jl"), dir[3])),
        walkdir(pkgSrcDir))
    close(io)
end

# Test package with overriden functions
function analyzePkg(pkg :: String)
    ENV["DYNAMIC_ANALYSIS_PACKAGE_NAME"] = pkg
    Pkg.add(pkg)
    collectSourceFilenames(pkg)
    Pkg.test(pkg)
end

# Override test method to include the overriden eval and invokeLatest
include("test-override.jl")
using Pkg
ENV["DYNAMIC_ANALYSIS_DIR"] = pwd()
analyzePkg(ARGS[1])
