using JSON

include("utils.jl")

# Expect JSON-file as input
if length(ARGS) == 0
    exitErrWithMsg("JSON-file name is expected as an argument")
end
const fname = ARGS[1]
if !isfile(fname)
    exitErrWithMsg("'$(fname)' is not a file")
end

# Read JSON data
allData = 
    try 
        JSON.parse(read(fname, String)) 
    catch e
        exitErrWithMsg(string(e))
    end

# Expected format: {packages: [...]}
const PKGS_KEY = "packages"

# Check that JSON has [packages] field
if !haskey(allData, PKGS_KEY)
    exitErrWithMsg("Wrong JSON: packages field is expected")
end

# Retrieve packages list
pkgsList = allData[PKGS_KEY]

# Sort packages
function getStarCount(pkgInfo :: Dict)
    metaData = pkgInfo["metadata"]
    haskey(metaData, "starcount") ? metaData["starcount"] : 0
end
sortedPkgsList = sort(pkgsList, by=getStarCount, rev=true)
#println(length(sortedPkgsList))

# Retrieve repo addresses, skipping the first pkg (which is julia itself)
getRepo(pkgInfo :: Dict) = pkgInfo["metadata"]["repo"]
topReposList = map(getRepo, sortedPkgsList[2:1001])

# Print repos
println(join(topReposList, "\n"))
println() # empty line in the end
