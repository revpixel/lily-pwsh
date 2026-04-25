## lily-pwsh
**A clean, minimal, zero‑drift PowerShell container built on Ubuntu 26.04.**

lily-pwsh is a sterile, reproducible PowerShell environment designed for people who want a predictable shell without host contamination, leftover apt cache, or the bloat of full Linux installs. It’s intentionally simple: build it, run it, throw it away. The image is the only persistent artifact.

## ✨ Features
**Minimal Ubuntu 26.04 base**
- Correct Microsoft repo for PowerShell
- No leftover apt cache or build debris
- Starts directly in pwsh
- Ephemeral by design — containers are disposable
- Optional persistent data directory via bind mount
- Works cleanly from Windows Terminal using SSH keys

## ⚠️ Prerequisites
This project assumes:

You already have Docker installed on your Linux host
(If not, check your distro’s documentation or Docker’s official install guide.)

You remember to mark any scripts in the scripts/ folder as executable
```
chmod +x scripts/<scriptname>
```

## 📦 Repository Contents
```
lily-pwsh/
└── docs/
    └── Install‑AzureModules.ps1 — README.md
    └── rebuild-scripts-README.md
└── examples/
    └── run-interactive.md
├── scripts/
│   ├── Install-AzureModules.ps1
│   ├── rebuild.sh
│   └── run-pwsh.sh
├── Dockerfile
├── README.md
```
## 🔧 Dockerfile Reminder Path
The Dockerfile includes a startup reminder:
```
CMD ["-NoLogo", "-Command", "Write-Host 'Reminder: Run ./mnt/repo-scripts/Install-AzureModules.ps1' -ForegroundColor Yellow; pwsh"]
```
This prints a message every time the container starts, reminding you to run your module‑install script from the persistent data mount.

If you store your script in a different location inside ```/mnt/data```, update the reminder path in the Dockerfile accordingly. The reminder is intentionally hard‑coded so users don’t forget to install modules into the persistent mount instead of baking them into the image.

## 🛠️ Building the Image
From the repo root:
```
docker build -t lily-pwsh .
```
> For details on the rebuild scripts (standard vs hard rebuild), see  
> [`docs/rebuild-scripts-README.md`](docs/rebuild-scripts-README.md).

This produces a clean, minimal PowerShell image with no drift and no cached apt layers.

## ▶️ Running the Container
Basic interactive shell
```docker run --rm -it lily-pwsh``` 
or 
```scripts/run-pwsh.sh```

With a persistent data directory
```
docker run --rm -it \
-v "$HOME/pwsh-data:/mnt/data" \
lily-pwsh
```

Anything placed in /mnt/data inside the container persists between runs.

## 🪟 Using It from Windows Terminal (SSH‑based workflow)
I run this container from Windows Terminal using SSH keys to authenticate to my Linux host. This avoids passwords, reduces friction, and makes the workflow feel native.

Example Windows Terminal profile command:

```
ssh -t <your-linux-user>@<your-linux-host> /home/<your-linux-user>/run-pwsh.sh
```

If someone needs SSH keys:
```
ssh-keygen -t ed25519 -C "your_email@example.com"
ssh-copy-id your-linux-host
```
After that, Windows Terminal launches the container instantly with no prompts.
<img width="1115" height="628" alt="image" src="https://github.com/user-attachments/assets/bc957325-05a5-4f76-83ad-ad7b119d3978" />

## 🧰 Installing PowerShell Modules (Persistent Bootstrap Script)
This container is intentionally sterile — no modules are baked into the image.
Modules are installed inside the container’s filesystem and do not persist across rebuilds.
If you restart or recreate the container, simply rerun the bootstrap script.

A helper script is included in the repo:
```
scripts/Install-AzureModules.ps1
```
Run it inside the container:
```
./mnt/repo-scripts/Install-AzureModules.ps1
```
What this script installs

This script sets up the complete **modern** Microsoft 365 / Azure admin toolchain, including:

- **Az** (Azure Resource Manager)
- **Microsoft.Graph** (GA + Beta)
- **Microsoft Graph workload modules**, including:
  - Authentication
  - Directory Management
  - Sign‑Ins
  - Security
  - Reports
  - Device Management
  - Identity Governance
  - Teams
- **ExchangeOnlineManagement** (EXO V3)
- **MicrosoftTeams** (Teams PowerShell module)
- **PnP.PowerShell** (SharePoint Online administration)

All modules installed by this script are **PowerShell 7‑compatible** and fully supported.

### What this script does

- Installs or updates all required modules  
- Removes all previously installed versions  
- Reinstalls clean copies to guarantee version alignment  
- Ensures a **zero‑drift**, reproducible module baseline  
- Produces deterministic results across containers, VMs, and rebuilds  

This keeps the environment **sterile**, predictable, and free of legacy dependencies.

### Legacy modules removed

The following deprecated modules have been intentionally excluded:

- AzureAD  
- AzureADPreview  
- MSOnline  

These modules are no longer supported in PowerShell 7 and are scheduled for retirement.  
Use the Windows PowerShell 5.1 environment (pwsh5) if you still require them.


You can run this script as often as you want to refresh or update modules without rebuilding the container. This keeps the image sterile while giving you a fully loaded, always‑current admin shell.
<img width="1115" height="628" alt="image" src="https://github.com/user-attachments/assets/cf9dccb1-1a54-4832-b055-09e4ba90f9dc" />

**📘 Full Documentation for Install‑AzureModules.ps1**
A full, detailed README for the Azure module installer script — including module lists, expected warnings, environment philosophy, and a complete example run — is available here:

👉 [Install‑AzureModules.ps1 — README.md](https://github.com/revpixel/lily-pwsh/blob/main/docs/Install%E2%80%91AzureModules.ps1%20%E2%80%94%20README.md)

This doc covers the why, the how, and the operational model behind the script, including sterile sandboxes, identity‑bound VMs, and deterministic module baselines.

**Why the container prints a reminder?**
On startup, the container prints:
```
Reminder: Run ./mnt/repo-scripts/Install-AzureModules.ps1
```
This ensures you don’t forget to install modules into the persistent mount the first time you run the container.

## 🧪 Philosophy: A Sterile, Ephemeral Lab
This project exists because I wanted a PowerShell environment that behaves like a clean lab:
- No drift — every container starts identical
- No contamination — nothing leaks into the host
- No bloat — only the required dependencies
- No surprises — deterministic builds
- No Desktop/WSL drama — pure Docker on a real Linux host
    
- The container is meant to be thrown away.
- The image is the only thing that persists.
- Everything else is ephemeral by design.

**Why admin modules aren’t baked into the image?**
- Azure, Microsoft 365, Graph, and Exchange modules change constantly.
- If they were included in the image, the container would drift, break, or require constant rebuilds.
- Installing them into the persistent mount keeps the image sterile and reproducible while letting the admin toolchain stay current.

## 🧹 Host hygiene (optional)
If you prefer a truly zero‑drift Docker host, you can optionally schedule a nightly docker system prune -f or similar cleanup task. This isn’t required for the container to function, but it complements the sterile‑lab workflow by keeping unused layers, networks, and build cache from accumulating over time. How you schedule it is up to you.

## 📜 License
- This project is released into the public domain / unlicensed.
- Do whatever you want with it.
