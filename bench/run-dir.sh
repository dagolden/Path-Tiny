#!/bin/bash
dir=$1
./harness.pl -t $dir
./chart-results.pl --sort=min -o $(basename $dir).png
