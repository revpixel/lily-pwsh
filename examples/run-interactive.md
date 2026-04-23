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
## 🪟 Using It from Windows Terminal (SSH‑based workflow)
Example Windows Terminal profile command:
```
ssh -t <your-linux-user>@<your-linux-host> /home/<your-linux-user>/run-pwsh.sh
```
> Windows Terminal can’t reliably run complex docker run commands directly, so this example uses a wrapper script to avoid quoting and path issues.
The script lives here: [`scripts/run-pwsh.sh`](https://github.com/revpixel/lily-pwsh/blob/main/scripts/run-pwsh.sh)).
