## lily-pwsh
**A clean, minimal PowerShell container built on Ubuntu 26.04.**

lily-pwsh is a sterile PowerShell environment for people who want a predictable shell without host contamination, leftover apt cache, or the bloat of a full Linux install. It's intentionally simple: build it, run it, throw it away. Every container started from the same image begins identical, and nothing leaks onto the host except the folders you choose to mount.

## 🚀 Quick Run (Prebuilt Container)
Run the prebuilt image:
```
docker run --rm -it ghcr.io/revpixel/lily-pwsh:stable
```
To keep your files and installed modules between runs:
```
docker run --rm -it --init \
  -v "$HOME/pwsh-data:/mnt/data" \
  -v "$HOME/pwsh-data/modules:/root/.local/share/powershell/Modules" \
  ghcr.io/revpixel/lily-pwsh:stable
```
The prebuilt image already includes the module installer at `/mnt/repo-scripts/Install-AzureModules.ps1`.

**Image tags**

| Tag | Built from | Use it for |
|---|---|---|
| `:stable` | `main` | Everyday use |
| `:dev` | `dev` | Trying upcoming changes before they reach `:stable` |
| `:2.0.40`, `:2.0-dev.3`, … | One exact build | Pinning a version (never changes) |

## 🆕 What's new in 2.0

**lily-pwsh 2.0 moves the base image from Ubuntu 24.04 to Ubuntu 26.04 LTS.**

The major version number changed because the operating system under PowerShell changed. A new Ubuntu LTS brings newer system libraries (ICU, OpenSSL, glibc), and those are what PowerShell and its modules load at runtime. Most scripts won't notice, but anything that depends on the OS underneath could behave differently. A major version makes that change visible, and lets you pin 1.x if you need to stay on 24.04.

| | 1.x | 2.x |
|---|---|---|
| Base image | Ubuntu 24.04 LTS | Ubuntu 26.04 LTS |
| PowerShell feed | Microsoft's Ubuntu 24.04 repo | Microsoft's Ubuntu 26.04 repo (native, no workaround) |
| CPU architecture | amd64 | amd64 only (Microsoft has no arm64 PowerShell package for 26.04 yet) |

2.0 also adds a dev channel: the `dev` branch publishes `:dev` images and pre-releases, so changes can be tested live before they reach `:stable`.

**Upgrading from 1.x**

- **`:stable` moves to 2.x automatically.** To stay on Ubuntu 24.04, pin the last 1.x build instead: `ghcr.io/revpixel/lily-pwsh:1.0.38`.
- **Re-run the module installer once.** Modules in your persistent `~/pwsh-data/modules` folder carry over, but a fresh install makes sure each one is the current version and works on 26.04:
  ```
  /mnt/repo-scripts/Install-AzureModules.ps1
  ```
- **Update your checkout** (`git pull` in `~/lily-pwsh`). If you mount the repo's `scripts/` folder (as `run-pwsh.sh` does), it overrides the installer built into the image, so an old checkout means an old installer.
- **On ARM hosts** (Raspberry Pi, Apple Silicon), stay on `1.0.38` until Microsoft publishes arm64 PowerShell for 26.04.

Tested before release: the current stable PowerShell on Ubuntu 26.04 LTS, with Az, Microsoft Graph and Graph Beta, Exchange Online, Microsoft Teams, PnP.PowerShell and Power BI all installing and loading.

> **Which exact versions?** Every build installs the newest stable PowerShell and the newest Ubuntu 26.04 point release (26.04.1, 26.04.2, …) available at build time, so they move forward on their own. Each build's [release notes](https://github.com/revpixel/lily-pwsh/releases) record the exact versions it contains.

## ✨ Features
**Minimal Ubuntu 26.04 base**
- PowerShell from Microsoft's official package feed
- No leftover apt cache or build debris
- Starts directly in pwsh
- Ephemeral by design: containers are disposable
- Optional persistent folders for your data and your modules
- Works cleanly from Windows Terminal using SSH keys

> 🧩 **Dependency Note:** `lily-pwsh` does not fork, vendor, or reference the Microsoft [PowerShell](https://github.com/PowerShell/PowerShell) GitHub repository.
> The container installs the current stable PowerShell runtime from Microsoft's official package feed.
> No upstream source code is included or modified. This is a clean runtime environment, not a PowerShell derivative.

## ⚠️ Prerequisites
- Docker installed on a Linux host (see your distro's documentation or Docker's official install guide).
- An x86-64 (amd64) host. Microsoft's Ubuntu 26.04 package feed has no arm64 PowerShell package yet, so the image can't be built on ARM machines such as a Raspberry Pi or an Apple Silicon Mac.
- The repo cloned to `~/lily-pwsh`, which is where `scripts/run-pwsh.sh` expects it:
```
  git clone https://github.com/revpixel/lily-pwsh.git ~/lily-pwsh
```
- The shell scripts marked executable:
```
  chmod +x ~/lily-pwsh/scripts/*.sh
```

## 📦 Repository Contents
```
lily-pwsh/
├── .github/
│   └── workflows/
│       ├── publish.yml          # builds main and publishes ghcr.io/revpixel/lily-pwsh:stable
│       └── publish-dev.yml      # builds dev and publishes ghcr.io/revpixel/lily-pwsh:dev
├── docs/
│   ├── Install-AzureModules.md  # full documentation for the module installer
│   └── rebuild-scripts-README.md
├── examples/
│   └── run-interactive.md
├── scripts/
│   ├── Install-AzureModules.ps1
│   ├── rebuild.sh
│   ├── rebuild-hard.sh
│   └── run-pwsh.sh
├── Dockerfile
├── LICENSE
└── README.md
```

## 🛠️ Building the Image
From the repo root:
```
docker build -t lily-pwsh .
```
> For the rebuild scripts (standard vs hard rebuild), see
> [`docs/rebuild-scripts-README.md`](docs/rebuild-scripts-README.md).

A fresh build installs the current Ubuntu updates and the current stable PowerShell. Docker caches those steps, though, so a repeat `docker build` (or `rebuild.sh`) reuses the packages from the last build. To pick up updates, run `scripts/rebuild-hard.sh`, which pulls a fresh Ubuntu base image and rebuilds with `--no-cache`. The prebuilt GHCR image is always built from scratch.

Because each fresh build gets whatever is current, two builds made weeks apart can differ. If you need byte-for-byte identical builds, pin the base image by digest and the `powershell` package version in the Dockerfile.

## ▶️ Running the Container
**Basic interactive shell** (nothing persists):
```
docker run --rm -it lily-pwsh
```

**Full setup with the wrapper script:**
```
~/lily-pwsh/scripts/run-pwsh.sh
```
The wrapper uses the locally built `lily-pwsh` image and mounts three folders:

| Host folder | Container path | Purpose |
|---|---|---|
| `~/pwsh-data` | `/mnt/data` | Your files; persists between runs |
| `~/lily-pwsh/scripts` | `/mnt/repo-scripts` | The repo's scripts, always the current version |
| `~/pwsh-data/modules` | `/root/.local/share/powershell/Modules` | Installed PowerShell modules; persists between runs and image rebuilds |

## 🪟 Using It from Windows Terminal (SSH-based workflow)
I run this container from Windows Terminal using SSH keys to authenticate to my Linux host. No passwords, no friction, and it feels native.

Example Windows Terminal profile command:
```
ssh -t <your-linux-user>@<your-linux-host> /home/<your-linux-user>/lily-pwsh/scripts/run-pwsh.sh
```

To set up SSH keys, create a key on Windows:
```
ssh-keygen -t ed25519 -C "your_email@example.com"
```
Then copy it to the Linux host. Windows OpenSSH doesn't include `ssh-copy-id`, so from PowerShell:
```
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh <your-linux-user>@<your-linux-host> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```
After that, Windows Terminal opens the container with no prompts. See [`examples/run-interactive.md`](examples/run-interactive.md) for a complete Windows Terminal profile.

<img width="1115" height="628" alt="Screenshot 2026-11-14 120602" src="https://github.com/user-attachments/assets/843f6694-ce51-4e9c-8fff-bf4ad2adeb18" />


## 🧰 Installing PowerShell Modules
No modules are baked into the image. Install them inside the container with the included script:
```
/mnt/repo-scripts/Install-AzureModules.ps1
```
With the modules folder mounted (as `run-pwsh.sh` does), the modules stay installed across container runs and image rebuilds. Re-run the script whenever you want to update them. Without that mount, modules exist only for the life of that container.

**What it installs** (the modern Microsoft 365 / Azure admin toolchain):
- **Az**: every Az.* service module
- **Microsoft.Graph** and **Microsoft.Graph.Beta**: full workload coverage, including Users, Groups, Identity, Security, Reports, Device Management and Teams
- **ExchangeOnlineManagement** (EXO V3), which also covers Security & Compliance
- **MicrosoftTeams**
- **PnP.PowerShell** for SharePoint Online (needs your own Entra ID app registration)
- **MicrosoftPowerBIMgmt** (optional; skip with `-CoreOnly`)

**What it does:**
- Looks up every module first, and stops before changing anything if one can't be found
- Removes all existing versions, including the sub-modules of Az and Microsoft.Graph that a normal uninstall leaves behind
- Installs one clean current version of each module and verifies it
- Reports what's installed and removes modules by section

```
/mnt/repo-scripts/Install-AzureModules.ps1 -Report     # what's installed
/mnt/repo-scripts/Install-AzureModules.ps1 -Remove     # remove by section (menu, Enter = all)
/mnt/repo-scripts/Install-AzureModules.ps1 -ShowPlan   # what would be installed
```

**Legacy modules:** AzureAD, AzureADPreview and MSOnline are deprecated and being retired by Microsoft in favor of Microsoft Graph PowerShell. The script never installs them; if it finds them, `-Report` flags them and `-Remove -Section Legacy` removes them.

The same script also runs on Windows, under both PowerShell 7 and Windows PowerShell 5.1, and handles the modules that belong to each. That makes it useful outside this container too.
<img width="1115" height="1061" alt="image" src="https://github.com/user-attachments/assets/963c19f7-55f4-49e2-a5dc-2ad3adaa77f2" />


**📘 Full documentation:** host profiles, every parameter, scopes, exit codes and limitations are covered in
👉 [`docs/Install-AzureModules.md`](docs/Install-AzureModules.md)

### Why the container prints a reminder
On startup the container prints:
```
Reminder: Run /mnt/repo-scripts/Install-AzureModules.ps1
```
That's set in the Dockerfile:
```
CMD ["-NoLogo", "-NoExit", "-Command", "Write-Host 'Reminder: Run /mnt/repo-scripts/Install-AzureModules.ps1' -ForegroundColor Yellow"]
```
It's there so you don't forget to install modules the first time. If you keep the script somewhere else, update the path in the Dockerfile.

## 🧪 Philosophy: A Sterile, Ephemeral Lab
This project exists because I wanted a PowerShell environment that behaves like a clean lab:
- **No drift:** every container from the same image starts identical
- **No contamination:** nothing leaks onto the host except the folders you mount
- **No bloat:** only the required dependencies
- **No surprises:** one clean version of each module, and a script that tells you exactly what's installed
- **No Desktop/WSL drama:** pure Docker on a real Linux host

The container is meant to be thrown away. The image, your data folder and your modules folder are the only things that persist, and you can wipe the modules any time with `-Remove -Section All` or by deleting `~/pwsh-data/modules`.

**Why aren't admin modules baked into the image?**
- Azure, Microsoft 365, Graph and Exchange modules change constantly.
- Baked in, they'd go stale and force constant image rebuilds.
- Keeping them in a mounted folder keeps the image small and clean, while the admin toolchain stays current on your schedule.

## 🧹 Host hygiene (optional)
For a Docker host that stays clean over time, you can schedule a nightly `docker system prune -f` or similar. It isn't required, but it keeps unused layers, networks and build cache from piling up. How you schedule it is up to you.

## 📜 License
Released into the public domain under [The Unlicense](LICENSE). Do whatever you want with it.
