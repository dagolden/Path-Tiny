#!/bin/bash
dir=$1
./dumbharness.pl -t $dir
./dumbchart.pl --sort=tiny -o $(basename $dir).png
