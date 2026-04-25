#!/bin/bash
set -e

echo "========================================="
echo "  Rebuilding lily-pwsh container image"
echo "========================================="

# Change to repo root (Dockerfile lives one level up from scripts/)
cd "$(dirname "$0")/.."

docker build -t lily-pwsh .

echo "========================================="
echo "  Rebuild complete."
echo "========================================="
