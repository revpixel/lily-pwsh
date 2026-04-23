#!/bin/bash
set -e

echo "Rebuilding lily-pwsh container..."

# Change to repo root (Dockerfile lives one level up from scripts/)
cd "$(dirname "$0")/.."

docker build -t lily-pwsh .

echo "Done."
