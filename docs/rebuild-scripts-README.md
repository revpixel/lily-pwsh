
## 🧱 Rebuilding the lily-pwsh Container
This repo includes two rebuild scripts under scripts/:

```rebuild.sh``` — the standard, safe, cached rebuild

```rebuild-hard.sh``` — the destructive, no‑cache, full reset rebuild

Both scripts intentionally change directory using:

```
cd "$(dirname "$0")/.."
```
This ensures the build context is always the repo root, regardless of where the script is executed from. The Dockerfile lives at the root, not inside scripts/, so this path correction is required for consistent, reproducible builds.

## 🔄 rebuild.sh — Standard Rebuild (Cached)
Use this for normal development and iterative changes.

- Does not stop or remove containers
- Does not delete the existing image
- Uses Docker’s build cache
- Fast, predictable, and safe
- Ideal for day‑to‑day workflow

This script is idempotent and non‑destructive. If you’re updating the Dockerfile, tweaking packages, or validating repo‑driven changes, this is the one you want.

## 🔥 rebuild-hard.sh — Full Teardown + No‑Cache Rebuild
Use this only when you need a guaranteed clean slate.

- Stops any running lily-pwsh container
- Removes the container
- Removes the old image
- Rebuilds with --no-cache
- Slower, but guarantees zero stale layers

This script is destructive by design. It’s useful when:

- Docker caching is hiding changes
- You’ve changed the base image
- You’re debugging weird behavior
- You want to validate the Dockerfile from absolute zero

If you don’t explicitly need a full teardown, use the standard rebuild instead.

## 🧭 When to Use Which
  | Aspect | Standard Rebuild (`rebuild.sh`) | Hard Rebuild (`rebuild-hard.sh`) |
  |--------|----------------------------------|-----------------------------------|
  | Purpose | Fast, cached rebuild | Full teardown + no‑cache rebuild |
  | Safety | Non‑destructive | Destructive (removes containers + image) |
  | Uses `$(dirname "$0")` | Yes | Yes |
  | Removes running container | No | Yes |
  | Removes old image | No | Yes |
  | Uses `--no-cache` | No | Yes |
  | Ideal for | Normal workflow, iterative changes | Debugging, cache issues, base image changes |
  | Speed | Fast | Slow |
  | Risk | Low | Medium |
  | Guarantees clean slate | No | Yes |

## 🧩 Why Two Scripts?
Because “rebuild” can mean two very different things:

- Rebuild using cache (fast, safe, workflow‑friendly)
- Rebuild from zero (slow, destructive, diagnostic‑grade)

Both are valid. They just solve different problems.

Keeping them separate prevents accidental environment destruction while still giving you a one‑command nuclear option when you actually need it.
