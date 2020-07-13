#!/bin/bash

# **************************************************
# Clones repositories listed in the given file
#   to the given directory.
# Default values: repos.txt and . (current directory)
# 
# Usage:
#     $ clone.sh [<folder>] [<fname>]
# Clones into <folder> repositories listed in <fname>
# **************************************************

USAGE="Usage:
    $ clone.sh <folder> <fname>
Clones into <folder> repositories listed in <fname>
By default (when no arguments): 
    $ clone.sh . repos.txt"
HELP="Use -h for help"

errexit () {
  echo "${HELP}"
  exit ${1}
}

# check for -h (help)
while getopts ":h" opt; do
  case ${opt} in
    h )
      echo "${USAGE}"
      exit 0
      ;;
    ? )
      echo "!ERROR: Invalid Option -$OPTARG" 1>&2
      errexit 1
      ;;
  esac
done

# default file name
fname="repos.txt"
# default directory
repdir="."

# check the arguments

if [[ $# -gt 2 ]]; then
  echo "!ERROR: Too many arguments" 1>&2
  errexit 1
fi

# first argument for target directory
if [[ $# -ge 1 ]]; then
  repdir="${1}"
fi
# second argument for file name
if [[ $# -ge 2 ]]; then
  fname="${2}"
fi

if [ ! -f "${fname}" ]; then
  echo "!ERROR: File ${fname} does not exist" 1>&2
  exit 2
fi
# we better have a new line ath the end of the file
lastline=$(tail -1 ${fname})
if [ "${lastline}" != "" ]; then
  echo "!ERROR: File ${fname} does not have an empty line at the end" 1>&2
  exit 2
fi
if [ ! -d "${repdir}" ]; then
  echo "!ERROR: Directory ${repdir} does not exist" 1>&2
  exit 2
fi

# ---------- actual work

echo "STATUS: Cloning repositories listed in ${fname} into ${repdir}"

# cheap solution for resolving fname in the current directory
# we can't just
#   cd "${repdir}"
# right here

#repos=$(<config.txt)
origdir=$(pwd)

repind=0
while read -r line; do
  if [ "${line}" != "" ]; then
    echo "-----STATUS (${repind}): Cloning ${line}"
    cd "${repdir}" # got the target directory
    git clone ${line}
    if [ $? -eq 0 ]; then
      repind=$((repind + 1))
    fi
  fi
  cd "${origdir}" # come back to the original directory
done < "${fname}"

echo "STATUS: Done -- ${repind} repositories have been cloned"

