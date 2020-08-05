# All Julia dependencies of the project
const DEPS = ["ArgParse", "JSON"]

# Install the dependencies
using Pkg
Pkg.add(DEPS)
