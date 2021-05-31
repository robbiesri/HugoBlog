#!/usr/bin/env bash

# if ! which proselint >/dev/null; then
#     echo -e "
# proselint is not set up. Please install it with pip3."
#     exit 1
# fi

if ! which markdownlint >/dev/null; then
    echo -e "
markdownlint-cli is not set up. Please install it with npm."
    exit 1
fi

for f in ./content/*.md;  do 
    echo "Checking ${f}"; 
    # echo "Running proselint..."; 
    # proselint ${f}; 
    echo "Running markdownlint..."; 
    markdownlint ${f};
done;

for f in ./content/post/*.md;  do 
    echo "Checking ${f}"; 
    # echo "Running proselint..."; 
    # proselint ${f}; 
    echo "Running markdownlint..."; 
    markdownlint ${f};
done;

for f in ./content/post/gfx/*.md;  do 
    echo "Checking ${f}"; 
    # echo "Running proselint..."; 
    # proselint ${f}; 
    echo "Running markdownlint..."; 
    markdownlint ${f};
done;