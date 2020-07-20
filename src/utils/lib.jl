# Clones all the repositories in the source file (where all the repo URL's are
# on their own line) into the given destination directory
function clone(source :: String, destination :: String)
    BASE_DIR = pwd()
    repoLinks = readlines(source)
    cloneEachRepo() = map((link) -> run(`git clone $(link)`), repoLinks)
    cd(cloneEachRepo, destination)
end
