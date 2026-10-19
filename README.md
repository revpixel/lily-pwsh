## lily-pwsh
**A clean, minimal PowerShell container built on Ubuntu 24.04.**

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

## ✨ Features
**Minimal Ubuntu 24.04 base**
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
│       └── publish.yml          # builds and publishes ghcr.io/revpixel/lily-pwsh:stable
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

Each build pulls the current Ubuntu updates and the current stable PowerShell, so the image stays up to date. That also means two builds made weeks apart can differ. If you need byte-for-byte identical builds, pin the base image by digest and the `powershell` package version in the Dockerfile.

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

<img width="1115" height="628" alt="image" src="https://github.com/user-attachments/assets/5835b6a1-fa1a-453f-aaf1-c1da5fa029f3" />

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
<img width="1115" height="1061" alt="image" src="https://github.com/user-attachments/assets/c1e9bdac-71dd-45ce-9cd6-edffd7b29370" />

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
