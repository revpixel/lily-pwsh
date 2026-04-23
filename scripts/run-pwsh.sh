#!/bin/bash
docker run --rm -it --init \
  -v "$HOME/pwsh-data:/mnt/data" \
  -v "$HOME/lily-pwsh/scripts:/mnt/repo-scripts" \
  lily-pwsh
