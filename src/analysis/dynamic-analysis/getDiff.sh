#!/bin/bash

pkgName=IJulia-1.21.3
stdioDir=package-data/$pkgName/stdio/
filePath=$stdioDir/analysis-stderr.txt
ltg=$(awk '/### DYNAMIC ANALYSIS LINE IDENTIFIER ###/ {print NR}' $filePath)
tail -n +$(($ltg+1)) $filePath | sed '/Status/d' | sed '/analyzePkg/d' | sed '/testPkg/d'
