#!/usr/bin/env bash

if ! which proselint >/dev/null; then
    echo -e "
proselint is not set up. Please install it with pip3."
    exit 1
fi

for f in ./content/*.md;  do 
    echo "Checking ${f}"; 
    proselint ${f}; 
done;

for f in ./content/post/*.md;  do 
    echo "Checking ${f}"; 
    proselint ${f}; 
done;