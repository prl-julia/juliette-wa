#!/bin/bash

function getAfterLineId {
    ltg=$(awk '/### DYNAMIC ANALYSIS LINE IDENTIFIER ###/ {print NR}' $1)
    returnVal=$(tail -n +$(($ltg+1)) $1 | sed '/Status/d' | sed '/analyzePkg/d' | sed '/testPkg/d')
}

function getDiff {
    getAfterLineId $1/analysis-$2.txt
    analysis=$returnVal
    getAfterLineId $1/test-$2.txt
    test=$returnVal
    returnVal=$(diff <(echo $analysis) <(echo $test))
}

haveDiffOut=()
haveDiffErr=()
packageDir=package-data
pkgs=$(ls $packageDir)
for pkg in $pkgs
do
    stdioDir=$packageDir/$pkg/stdio/
    getDiff $stdioDir stdout
    outDiff=$returnVal
    if [ -n "$outDiff" ]; then
	haveDiffOut+=( $pkg )
	echo $outDiff > $stdioDir/stdout-diff.txt
    fi
    getDiff $stdioDir stderr
    errDiff=$returnVal
    if [ -n "$errDiff" ]; then
	haveDiffErr+=( $pkg )
	echo $errDiff > $stdioDir/stderr-diff.txt
    fi
done
echo \#\#\# Have Different Stdout \#\#\#
printf '%s\n' ${haveDiffOut[@]}
echo \#\#\# Have Different Stderr \#\#\#
printf '%s\n' ${haveDiffErr[@]}
