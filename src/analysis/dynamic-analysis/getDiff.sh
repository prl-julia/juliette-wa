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

pkgs=$(ls package-data-tst)
for pkg in $pkgs
do
    stdioDir=package-data-tst/$pkg/stdio/
    getDiff $stdioDir stdout
    outDiff=$returnVal
    getDiff $stdioDir stderr
    errDiff=$returnVal
    echo \#\#\# OUT DIFF \#\#\#
    echo $outDiff
    echo \#\#\# ERR DIFF \#\#\#
    echo $errDiff
done
