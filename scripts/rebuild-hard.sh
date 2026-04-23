#!/bin/bash
# rebuild-hard.sh — Fully tear down and rebuild the lily-pwsh container image
# Use this only when you need a guaranteed clean slate.

set -e

echo "========================================="
echo "  HARD REBUILD: lily-pwsh container image"
echo "========================================="

# Change to repo root (Dockerfile lives one level up from scripts/)
cd "$(dirname "$0")/.."

# Stop and remove any running lily-pwsh containers
docker stop lily-pwsh 2>/dev/null || true
docker rm lily-pwsh 2>/dev/null || true

# Remove the old image
docker rmi lily-pwsh 2>/dev/null || true

# Build fresh with no cache
docker build --no-cache -t lily-pwsh .

echo "========================================="
echo "  lily-pwsh hard rebuild complete."
echo "  Run with: docker run -it --rm lily-pwsh"
echo "========================================="