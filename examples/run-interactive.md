# Running lily-pwsh Interactively

Ways to start a lily-pwsh shell, from a throwaway session to a Windows Terminal tab that opens the container on your Linux host over SSH.

| I want to… | Use |
|---|---|
| Try it once, keep nothing | [Quick run](#-quick-run) |
| Keep my files and installed modules | [Persistent run](#-persistent-run) |
| Run my own local build | [Local image](#-local-image) |
| Start it the same way every time | [Wrapper script](#-wrapper-script) |
| Open it from a Windows Terminal tab | [Windows Terminal](#-windows-terminal) |

---

## 🚀 Quick run

Pull the prebuilt image and drop straight into PowerShell:

```bash
docker run --rm -it ghcr.io/revpixel/lily-pwsh:stable
```

`--rm` deletes the container when you exit, so nothing you do here is kept.

> **Tags:** `:stable` always points to the newest build of `main`. `:dev` points to the newest build of the `dev` branch, for trying upcoming changes. To stay on one exact build, use its version tag (for example `:2.0.40` or `:2.0-dev.3`). The [Releases](https://github.com/revpixel/lily-pwsh/releases) page lists each version, with dev builds marked as pre-releases. To pick up a newer `:stable`, run `docker pull ghcr.io/revpixel/lily-pwsh:stable`.

## 💾 Persistent run

Mount a data folder and a modules folder from the host so your files and modules survive between runs:

```bash
docker run --rm -it --init \
  -v "$HOME/pwsh-data:/mnt/data" \
  -v "$HOME/pwsh-data/modules:/root/.local/share/powershell/Modules" \
  ghcr.io/revpixel/lily-pwsh:stable
```

| Host folder | Container path | Holds |
|---|---|---|
| `~/pwsh-data` | `/mnt/data` | Your files |
| `~/pwsh-data/modules` | `/root/.local/share/powershell/Modules` | Modules installed with `Install-AzureModules.ps1` |

`--init` adds a small init process so Ctrl+C and `docker stop` shut the shell down cleanly.

## 🔨 Local image

If you built the image yourself (`docker build -t lily-pwsh .` or [`scripts/rebuild.sh`](../scripts/rebuild.sh)), use `lily-pwsh` instead of the GHCR name:

```bash
docker run --rm -it lily-pwsh
```

The same `-v` options from [Persistent run](#-persistent-run) work here too.

## 📜 Wrapper script

[`scripts/run-pwsh.sh`](../scripts/run-pwsh.sh) runs the local `lily-pwsh` image with `--init` and three mounts:

- `~/pwsh-data` → `/mnt/data` for your files.
- `~/pwsh-data/modules` → `/root/.local/share/powershell/Modules`, so installed modules are kept.
- The repo's `scripts/` folder → `/mnt/repo-scripts`. The container then uses the copy of `Install-AzureModules.ps1` in your checkout instead of the one in the image, so `git pull` is enough to update it.

```bash
~/lily-pwsh/scripts/run-pwsh.sh
```

The script expects the repo at `~/lily-pwsh`. If it says `Permission denied`, make it executable:

```bash
chmod +x ~/lily-pwsh/scripts/*.sh
```

## 🪟 Windows Terminal

### Option A: container on a Linux host, over SSH

Windows Terminal runs the wrapper script on your Linux host over SSH. The wrapper keeps the long `docker run` command (with all its quoting) out of Windows Terminal.

1. Set up key-based SSH to the host (see [the README](../README.md#-using-it-from-windows-terminal-ssh-based-workflow)), so the tab opens without a password prompt.
2. Open Windows Terminal → **Settings** → **Open JSON file**, and add this to `profiles.list`:

```json
{
    "name": "lily-pwsh",
    "commandline": "ssh -t <your-linux-user>@<your-linux-host> /home/<your-linux-user>/lily-pwsh/scripts/run-pwsh.sh",
    "tabTitle": "lily-pwsh",
    "suppressApplicationTitle": true,
    "startingDirectory": "%USERPROFILE%",
    "font": {
        "face": "Cascadia Code",
        "size": 11
    },
    "hidden": false
}
```

`-t` gives SSH a terminal, which the interactive shell needs. Without it you get no prompt.

### Option B: Docker Desktop on Windows

If Docker runs on the same Windows machine, the profile can call Docker directly. Keep the command short and on one line:

```json
{
    "name": "lily-pwsh (local)",
    "commandline": "docker run --rm -it ghcr.io/revpixel/lily-pwsh:stable",
    "tabTitle": "lily-pwsh",
    "suppressApplicationTitle": true
}
```

For persistent folders on Windows, add mounts such as `-v %USERPROFILE%\\pwsh-data:/mnt/data` to the command (inside JSON, each backslash is written twice).

## 🧭 Inside the container

When the shell starts you'll see:

```
Reminder: Run /mnt/repo-scripts/Install-AzureModules.ps1
```

Install the Azure / Microsoft 365 modules:

```powershell
/mnt/repo-scripts/Install-AzureModules.ps1
```

Without the modules mount, they're gone when the container exits. With it, they're installed once and kept. Full options are in the [installer docs](../docs/Install-AzureModules.md).

Type `exit` to leave. With `--rm`, the container is deleted at that point.

## 🩺 Troubleshooting

| Symptom | Fix |
|---|---|
| `permission denied ... docker.sock` | Add your user to the `docker` group (`sudo usermod -aG docker $USER`), then log out and back in. |
| `Unable to find image 'lily-pwsh:latest'` | You haven't built the local image. Run `scripts/rebuild.sh`, or use `ghcr.io/revpixel/lily-pwsh:stable`. |
| Windows Terminal tab opens and closes immediately | Run the same `ssh -t ...` command in a normal terminal to see the error. Usually it's the script path or SSH keys. |
| No prompt over SSH | Make sure the command uses `ssh -t`. |
| Modules missing after restart | Mount `~/pwsh-data/modules` as shown in [Persistent run](#-persistent-run). |
