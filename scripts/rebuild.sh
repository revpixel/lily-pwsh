#!/bin/bash
set -e

echo "Rebuilding lily-pwsh container..."

# Change to the directory where the Dockerfile lives
cd "$(dirname "$0")/.."

docker build -t lily-pwsh .

echo "Done."
