#!/usr/bin/env bash
set -euo pipefail

make clean
make

mkdir -p out
cp ./reverse ./out/reverse
chmod +x ./out/reverse

echo "Build completed: ./out/reverse"
