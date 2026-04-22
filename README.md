## lily-pwsh
## A clean, minimal, zero‑drift PowerShell container built on Ubuntu 24.04.

lily-pwsh is a sterile, reproducible PowerShell environment designed for people who want a predictable shell without host contamination, leftover apt cache, or the bloat of full Linux installs. It’s intentionally simple: build it, run it, throw it away. The image is the only persistent artifact.

## ✨ Features
Minimal Ubuntu 24.04 base

Correct Microsoft repo for PowerShell

No leftover apt cache or build debris

Starts directly in pwsh

Ephemeral by design — containers are disposable

Optional persistent data directory via bind mount

Works cleanly from Windows Terminal using SSH keys

## 📦 Repository Contents
```lily-pwsh/
├── Dockerfile
├── README.md
├── scripts/
│   └── rebuild.sh
└── examples/
    └── run-interactive.md
```
🛠️ Building the Image
From the repo root:

docker build -t lily-pwsh .

This produces a clean, minimal PowerShell image with no drift and no cached apt layers.

## ▶️ Running the Container
Basic interactive shell
docker run --rm -it lily-pwsh

With a persistent data directory
docker run --rm -it \
-v "$HOME/pwsh-data:/mnt/data" \
lily-pwsh

Anything placed in /mnt/data inside the container persists between runs.

## 🪟 Using It from Windows Terminal (SSH‑based workflow)
I run this container from Windows Terminal using SSH keys to authenticate to my Linux host. This avoids passwords, reduces friction, and makes the workflow feel native.

Example Windows Terminal profile command:

ssh your-linux-host "docker run --rm -it -v ~/pwsh-data:/mnt/data lily-pwsh"

If someone needs SSH keys:

ssh-keygen -t ed25519 -C "your_email@example.com"
ssh-copy-id your-linux-host

After that, Windows Terminal launches the container instantly with no prompts.

## 🧪 Philosophy: A Sterile, Ephemeral Lab
This project exists because I wanted a PowerShell environment that behaves like a clean lab:

No drift — every container starts identical

No contamination — nothing leaks into the host

No bloat — only the required dependencies

No surprises — deterministic builds

No Desktop/WSL drama — pure Docker on a real Linux host

The container is meant to be thrown away.
The image is the only thing that persists.
Everything else is ephemeral by design.

📜 License
This project is released into the public domain / unlicensed.
Do whatever you want with it.
