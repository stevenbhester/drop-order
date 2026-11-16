#!/bin/zsh
# Builds the level engine: build/lm
cd "${0:A:h}/../.."
mkdir -p build
clang -O2 -Wall -Wextra -Wno-unused-function -o build/lm tools/engine/lm.c -lm && echo "built build/lm"
