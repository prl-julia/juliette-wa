import Base.show

# Single file statistics
struct FileStat
    eval         :: UInt # number of calls to eval
    invokelatest :: UInt # number of calls to invokelatest
end

function Base.show(io::IO, stat::FileStat)
  print(io, "{ev: $(Int(stat.eval)), il: $(Int(stat.invokelatest))}")
end

# Checks if statistics is "interesting", i.e. non-zero
isInteresting(stat :: FileStat) :: Bool =
    #stat.invokelatest > 0
    (stat.eval + stat.invokelatest) > 0

# Statistics about package
struct PackageStat
    totalFiles       :: UInt # number of source files
    failedFiles      :: UInt # number of files that fail to process
    interestingFiles :: UInt # number of files with eval/invokelatest
    filesStat        :: Dict{String, FileStat} # File name => statistics`
end

function Base.show(io::IO, stat::Dict{String, FileStat})
    for info in stat
        println("* $(info[1]) => $(info[2])")
    end
end

# function call where \W means non-word character
# (to exclude cases such as "my_eval(")
const PATTERN_EVAL = r"\Weval\(" #"eval("
const PATTERN_INVOKELATEST = r"\Winvokelatest\(" #"invokelatest("

# Computes statistics for source code [text]
computeStat(text :: String) :: FileStat =
    FileStat(count(PATTERN_EVAL, text), count(PATTERN_INVOKELATEST, text))

function processPkg(pkgPath :: String)
    totalFiles = 0
    failedFiles = 0
    interestingFiles = 0
    filesStat = Dict{String, FileStat}()
    srcPath = joinpath(pkgPath, "src")
    if !isdir(srcPath)
        return nothing
    end
    for (root, _, files) in walkdir(srcPath)
        totalFiles += length(files)
        for file in files
            fname = joinpath(root, file)
            stat = computeStat(read(fname, String))
            if isInteresting(stat)
                interestingFiles += 1
                filesStat[fname[length(srcPath)-2:end]] = stat
            end
        end
    end
    PackageStat(totalFiles, failedFiles, interestingFiles, filesStat)
end

function processPkgsDir(path :: String)
    stats = Dict{String,Union{PackageStat, Nothing}}()
    for name in readdir(path)
        pkgPath = joinpath(path, name) 
        if isdir(pkgPath)
            pkgInfo = processPkg(pkgPath)
            if pkgInfo != nothing
                stats[name] = pkgInfo
            end
        end
    end
    stats
end
