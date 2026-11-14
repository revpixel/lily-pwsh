#!/bin/bash
docker run --rm -it --init \
  -v "$HOME/pwsh-data:/mnt/data" \
  -v "$HOME/lily-pwsh/scripts:/mnt/repo-scripts" \
  -v "$HOME/pwsh-data/modules:/root/.local/share/powershell/Modules" \
  lily-pwsh
