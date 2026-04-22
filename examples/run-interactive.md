# Running lily-pwsh Interactively

This guide shows several ways to run the `lily-pwsh` container, from a simple local shell to a fully remote workflow using Windows Terminal and SSH keys.

---

## 🟢 Basic Interactive Shell

Run the container and drop directly into PowerShell:

```
docker run --rm -it lily-pwsh
```
Run the container with a persistent mounted data folder and drop directly into PowerShell:
```
docker run --rm -it --init -v "$HOME/pwsh-data:/mnt/data" lily-pwsh
```