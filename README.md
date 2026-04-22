# lily-pwsh  
A clean, minimal, zero‑drift PowerShell container built on Ubuntu 24.04.

`lily-pwsh` is a sterile, reproducible PowerShell environment designed for people who want a predictable shell without host contamination, leftover apt cache, or the bloat of full Linux installs. It’s intentionally simple: build it, run it, throw it away. The image is the only persistent artifact.

---

## ✨ Features

- Minimal Ubuntu 24.04 base  
- Correct Microsoft repo for PowerShell  
- No leftover apt cache or build debris  
- Starts directly in `pwsh`  
- Ephemeral by design — containers are disposable  
- Optional persistent data directory via bind mount  
- Works cleanly from Windows Terminal using SSH keys  

---

## 📦 Repository Contents

