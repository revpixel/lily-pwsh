# Rebuilding the lily-pwsh Image

Two scripts in [`scripts/`](../scripts) rebuild the local `lily-pwsh` image:

| Script | What it does | Use it for |
|---|---|---|
| [`rebuild.sh`](../scripts/rebuild.sh) | Cached rebuild. Fast and non-destructive. | Everyday changes to the Dockerfile or scripts |
| [`rebuild-hard.sh`](../scripts/rebuild-hard.sh) | Removes the old image, pulls a fresh Ubuntu base and rebuilds with `--no-cache` | A clean slate: stale layers, package updates, odd behavior |

Both scripts `cd` to the repo root first, so you can run them from anywhere:

```bash
cd "$(dirname "$0")/.."
```

The Dockerfile lives at the repo root, and the build copies `scripts/Install-AzureModules.ps1` into the image, so the build has to run from there.

> **Don't need a local build?** The prebuilt image is published for every change to `main`:
> `docker pull ghcr.io/revpixel/lily-pwsh:stable`. See [Publishing a fresh build](#-publishing-a-fresh-build) below.
>
> ← Back to the [main README](../README.md)

## 🔄 rebuild.sh: standard rebuild

```bash
~/lily-pwsh/scripts/rebuild.sh
```

- Runs `docker build -t lily-pwsh .`
- Uses Docker's build cache, so unchanged steps are skipped
- Doesn't stop containers or delete anything
- Safe to run as often as you like

**Catch:** because the `apt-get update && apt-get upgrade` step is cached, a cached rebuild does **not** pick up new Ubuntu or PowerShell package updates. Only changes to the Dockerfile, or to files it copies in, cause steps to run again. For updates, use the hard rebuild.

## 🔥 rebuild-hard.sh: clean rebuild

```bash
~/lily-pwsh/scripts/rebuild-hard.sh
```

- Stops and removes a container **named** `lily-pwsh`, if there is one
- Removes the `lily-pwsh` image
- Pulls the newest `ubuntu:24.04` base image (`--pull`), the same fresh start the published image gets
- Rebuilds with `--no-cache`, so every step runs again, including `apt-get upgrade`, and you get current Ubuntu and PowerShell packages
- Slower, but no stale layers

Every step ignores "not found" errors, so it's safe to run even when nothing exists yet.

**Before you run it:**

- **Exit any open lily-pwsh shells.** Containers started by `run-pwsh.sh` or `docker run --rm` get random names, so the script's `docker stop lily-pwsh` doesn't find them. If one is still running, the old image can't be removed. The build still succeeds, but the old image is left behind untagged. Run `docker image prune` afterwards to clean it up.
- **Your data and modules are safe.** They live in the host folders under `~/pwsh-data`, not in the image.

## 🧭 Which one?

| | `rebuild.sh` | `rebuild-hard.sh` |
|---|---|---|
| Base image | Local copy of `ubuntu:24.04` | Newest `ubuntu:24.04` (`--pull`) |
| Build cache | Used | Ignored (`--no-cache`) |
| Picks up Ubuntu / PowerShell updates | No | Yes |
| Removes the old image | No | Yes |
| Stops containers | No | Only one named `lily-pwsh` |
| Speed | Seconds when cached | Minutes |
| Risk | None | Low: removes the image only, never your data |
| Use when | Iterating on the Dockerfile or scripts | You want updates, a clean slate, or you're chasing odd behavior |

If you're not sure, start with `rebuild.sh`.

## 🚀 Publishing a fresh build

The GHCR image is built by GitHub Actions ([`publish.yml`](../.github/workflows/publish.yml)), not by these scripts. Each run:

- Builds from scratch on a clean runner, so it always gets current packages
- Pushes `ghcr.io/revpixel/lily-pwsh:<version>` and moves `:stable` to it
- Creates a GitHub Release with the PowerShell and Ubuntu versions it contains

It runs automatically on every push to `main`. To rebuild without a code change (for example, to pick up Ubuntu security updates), open **Actions → Build and Publish lily-pwsh Image → Run workflow** and enter a reason. Or use the GitHub CLI:

```bash
gh workflow run publish.yml -f reason="Ubuntu security updates"
```

Version numbers are the `MAJOR.MINOR` from [`VERSION`](../VERSION) plus the workflow run number, so every run gets a new version (for example `1.0.34`).

## 🧩 Why two scripts?

"Rebuild" means two different things:

- **Rebuild what changed:** fast, cached, for everyday work.
- **Rebuild from zero:** slow, removes the old image, gets current packages and rules out the cache.

Keeping them separate means the everyday command never deletes anything by accident, and the full reset is still one command away.
