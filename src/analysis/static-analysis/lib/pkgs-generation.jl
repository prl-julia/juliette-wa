
#**********************************************************************
# Generation of a list of most starred Julia packages
# with the exception of Julia itself
#**********************************************************************

#--------------------------------------------------
# Imports
#--------------------------------------------------

using JSON

# Just in case, we don't want to include code repeatedly
Core.isdefined(Main, :UTILS_DEFINED) ||
    include("../../../utils/lib.jl")

###################################################
# Constants and Parameters
###################################################

# API for getting JSON with info about Julia packages
# from official Julia Computing web page
const PKGS_INFO_URL = "https://juliahub.com/app/packages/info"
# Expected format of JSON data: {packages: [...]}
const PKGS_KEY = "packages"

# Repositories of bad packages that might be in the list
# (submitted an issue: https://github.com/JuliaComputing/JuliaHub/issues/67)
const BAD_PKGS = [
    # Julia repo itself we don't check
    "https://github.com/JuliaLang/julia.git",
    # Decentralized-Internet isn't a Julia package
    "https://github.com/Lonero-Team/Decentralized-Internet.git",
    # Empty package, it was merged somewhere
    "https://github.com/dmlc/MXNet.jl.git",
    # Renamed to Franklin.jl
    "https://github.com/tlienart/JuDoc.jl.git",
    # Packages below aren't publicly accessible for some reason
    "https://github.com/JuliaComputing/Blpapi.jl.git",
    "https://github.com/bcbi/CountdownLetters.jl.git",
    "https://github.com/JuliaComputing/MiletusPro.jl.git",
    "https://github.com/aramirezreyes/SAMtools.jl.git",
    "https://github.com/bcbi/CountdownNumbers.jl.git",
    "https://github.com/JuliaComputing/JuliaInXL.jl.git",
    "https://github.com/tlienart/MLJScikitLearn.jl.git",
    "https://github.com/PetrKryslUCSD/MeshKeeper.jl.git",
    "https://github.com/PetrKryslUCSD/MeshPorter.jl.git",
    "https://github.com/PetrKryslUCSD/MeshFinder.jl.git",
    "https://github.com/PetrKryslUCSD/MeshMaker.jl.git",
    "https://github.com/rjdverbeek-tud/Atmosphere.jl.git",
    "https://github.com/PumasAI/Bioequivalence.jl.git",
    "https://github.com/mrtkp9993/Bioinformatics.jl.git",
    "https://github.com/anders-dc/Granular.jl.git",
    "https://github.com/rbalexan/InfrastructureSensing.jl.git",
    "https://github.com/slmcbane/MirroredArrayViews.jl.git",
    "https://github.com/oscar-system/GAPTypes.jl.git",
    "https://github.com/StanJulia/StanMCMCChain.jl.git",
    "https://github.com/markushhh/YahooFinance.jl.git",
]

###################################################
# Retrieve complete packages information
###################################################

function loadPkgsList(pkgsInfoFileName :: String, reload :: Bool = false)
    # Dowload packages info if needed
    if !isfile(pkgsInfoFileName) || reload
        @info("Downloading packages info...")
        download(PKGS_INFO_URL, pkgsInfoFileName)
        @info("Downloading completed")
    end
    # Read JSON info about packages
    @info("Loading packages info...")
    pkgsInfo = 
        try 
            JSON.parse(read(pkgsInfoFileName, String)) 
        catch e
            exitErrWithMsg(string(e))
        end
    # Check that JSON has [packages] field
    if !haskey(pkgsInfo, PKGS_KEY)
        exitErrWithMsg("Wrong JSON: packages field is expected")
    end
    # Retrieve list of packages information
    pkgsList = pkgsInfo[PKGS_KEY]
    @info("Loading completed")
    pkgsList
end

###################################################
# Process list of packages
###################################################

#--------------------------------------------------
# Aux functions
#--------------------------------------------------

# Dict (pkg info), String → Any
# Retrieves value of [key] from [pkgInfo] metadata or returns [default]
function getMetaDataValue(pkgInfo :: Dict, key :: String, default :: Any)
    # in case the value of the element is `null` in JSON
    val =
        if haskey(pkgInfo, "metadata") 
            metaData = pkgInfo["metadata"]
            haskey(metaData, key) ? metaData[key] : default
        else
            default
        end
    val === nothing ? default : val
end

# Dict (pkg info) → Int
# Returns the number of stars if available
getStarCount(pkgInfo :: Dict) = getMetaDataValue(pkgInfo, "starcount", 0)

# Dict (pkg info) → String
# Returns the repository address if available
getRepo(pkgInfo :: Dict) = getMetaDataValue(pkgInfo, "repo", "<NA-repo>")

# Dict (pkg info) → String
# Returns package name if available
getName(pkgInfo :: Dict) = haskey(pkgInfo, "name") ? pkgInfo["name"] : "<NA-name>"

#--------------------------------------------------
# Processing
#--------------------------------------------------

function processPkgsList(pkgsList :: Vector, showName :: Bool = false) :: Vector
    # Remove Julia itself and other blacklisted packages
    @info("Cleaning packages...")
    pkgsList = filter(pkg -> !in(getRepo(pkg), BAD_PKGS), pkgsList)
    @info("Cleaning completed")
    # Sort packages from most to least starred
    @info("Sorting packages...")
    pkgsList = sort(pkgsList, by=getStarCount, rev=true)
    @info("Sorting completed")
    # Required information depends on the parameters
    getInfo = showName ? getName : getRepo
    # Get required information about the top pkgsNum packages
    # Note. We use unique because the package list sometimes has duplicates,
    #       e.g. https://github.com/JuliaPlots/StatsPlots.jl.git
    topPkgsInfoList = unique(map(getInfo, pkgsList))
    topPkgsInfoList
end

###################################################
# Output required information
###################################################

function outputPkgsInfoList(pkgsInfoList :: Vector, pkgsNum :: Int, 
    pkgsListFileName :: String, show :: Bool = false
)
    @info("Ready to output the result")
    # Check and possibly fix the number of packages
    if pkgsNum < 0
        pkgsNum = 1
        @warn("requested number of packages cannot be negative -- set to $(pkgsNum)")
    elseif pkgsNum > length(pkgsInfoList)
        pkgsNum = length(pkgsInfoList)
        @warn("requested number of packages is too big -- set to $(pkgsNum)")
    end
    pkgsInfoList = pkgsInfoList[1:pkgsNum]
    # Prepare output
    output = join(pkgsInfoList, "\n")
    # Output
    if show
        println(output)
    else 
        #=
        if isfile(pkgsListFileName)
            println("File $(pkgsListFileName) already exists. Do you want to overwrite it? (y/N)")
            readline() == "y" || exit()
        end
        =#
        open(pkgsListFileName, "w") do io
            write(io, output)
        end
        @info("Output completed")
    end
end

###################################################
# Do everything
###################################################

function generatePackagesList(
    pkgsInfoFileName :: String, reload :: Bool,
    showName :: Bool, pkgsNum :: Int,
    pkgsListFileName :: String, show :: Bool
)
    pkgsList = loadPkgsList(pkgsInfoFileName, reload)
    pkgsInfoList = processPkgsList(pkgsList, showName)
    outputPkgsInfoList(pkgsInfoList, pkgsNum, pkgsListFileName, show)
end

generatePackagesList(
    pkgsInfoFileName :: String, reload :: Bool,
    pkgsNum :: Int, pkgsListFileName :: String
) = generatePackagesList(
    pkgsInfoFileName, reload, 
    false, pkgsNum,
    pkgsListFileName, false
)