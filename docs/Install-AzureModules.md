# Install-AzureModules.ps1

Installs, reports on, and cleans up the PowerShell modules used for Azure, Microsoft Graph and Microsoft 365 administration. It detects which PowerShell it is running in and only handles the modules that belong there, so the same script works on a Windows workstation, a Windows VM, and a Linux container.

It is built for repeatable environments: sandboxes, VM baselines, and container images where you want exactly one version of each module and nothing left over from earlier installs.

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Host profiles](#host-profiles)
- [Modes](#modes)
- [Parameters](#parameters)
- [Sections](#sections)
- [Scopes and what the script can and cannot remove](#scopes-and-what-the-script-can-and-cannot-remove)
- [Running in a container](#running-in-a-container)
- [Exit codes](#exit-codes)
- [Notes and limitations](#notes-and-limitations)

## Requirements

| Host | Requirement |
|---|---|
| PowerShell 7 | 7.4 or later, major version 7 only. PSResourceGet ships in the box. |
| Windows PowerShell | 5.1 with .NET Framework 4.7.2 or later. PSResourceGet is installed automatically on first run. |
| Network | Access to the PowerShell Gallery, or your own feed via `-Repository`. `-Report` and `-ShowPlan` work offline. |
| Elevation | Only for `-Scope AllUsers` or `-Scope Both`: Administrator on Windows, root on Linux. |

Any other host (PowerShell 6.x, 7.0 to 7.3, a future 8.x, or Windows PowerShell older than 5.1) is refused with exit code 2.

## Quick start

```powershell
# See what would happen on this host. Changes nothing.
./Install-AzureModules.ps1 -ShowPlan

# Install everything for this host (current user).
./Install-AzureModules.ps1

# See what is installed.
./Install-AzureModules.ps1 -Report

# Remove modules, choosing sections from a menu (Enter = all).
./Install-AzureModules.ps1 -Remove
```

On Windows you run it twice to cover both shells: once from `pwsh` for the modern modules and once from `powershell.exe` for the modules that still need Windows PowerShell. The script says this at the end of each run.

## Host profiles

The script picks one of three profiles from the PowerShell it is running in.

| Profile | Host | Installs |
|---|---|---|
| `PwshLinux` | pwsh 7.4+ on Linux (macOS uses this profile too) | Az, Microsoft.Graph, Microsoft.Graph.Beta, ExchangeOnlineManagement, MicrosoftTeams, PnP.PowerShell, MicrosoftPowerBIMgmt (optional) |
| `PwshWindows` | pwsh 7.4+ on Windows | Same set as `PwshLinux` |
| `WinPS` | Windows PowerShell 5.1 | Only the modules that need it: Microsoft.Online.SharePoint.PowerShell, plus Microsoft.PowerApps.Administration.PowerShell, Microsoft.PowerApps.PowerShell and MSCommerce (optional) |

The two pwsh profiles install the same modules today. They are separate so a platform-specific module can be added to one without affecting the other.

### Cleanup-only modules

Every module in the catalog is known on every host. Where a module's profile does not match, it is never installed there, but `-Report` lists it and `-Remove` can remove it. That catches things like an old `Microsoft.Graph` install sitting in Windows PowerShell's module folder.

The **Legacy** section (AzureAD, AzureADPreview, MSOnline) is cleanup-only everywhere. These modules are deprecated and the script never installs them.

## Modes

Choose one mode per run.

### Install (default)

```powershell
./Install-AzureModules.ps1 [-CoreOnly] [-SkipUninstall] [-Scope CurrentUser|AllUsers] [-Repository <name>]
```

1. Looks up every planned module in the repository first. If **any** lookup fails, the script stops before uninstalling anything, so a gallery outage never leaves you with an empty environment.
2. Removes every installed version of each planned module in the target scope. This includes the sub-modules of meta packages (`Az.*`, `Microsoft.Graph*`, `MicrosoftPowerBIMgmt.*`), which a plain uninstall of the meta package leaves behind.
3. Installs exactly the versions found in step 1 and verifies each one.
4. Prints a summary and warns about copies in the other scope, copies it cannot manage, and cleanup-only modules present on the host.

Install never touches cleanup-only modules. It names them and gives you the `-Remove` command instead.

### Show plan

```powershell
./Install-AzureModules.ps1 -ShowPlan
```

Prints the detected profile, the modules that would be installed, and the cleanup-only modules for this host. Changes nothing and needs no network.

### Report

```powershell
./Install-AzureModules.ps1 -Report
```

Lists installed modules from the catalog, grouped by section, with columns for:

- **CurrentUser**: versions in the per-user module folder
- **AllUsers**: versions in the machine-wide module folder
- **Other**: copies that load on this host but that the script cannot remove (see below)
- **Notes**: `cleanup only`, `multiple copies`, `optional`

Meta-package sections also show a sub-module count. Installable modules are always listed; cleanup-only modules appear only when a copy is found. Works offline and needs no elevation.

### Remove

```powershell
# Interactive: numbered menu of installed sections, Enter = all, then a y/N confirmation.
./Install-AzureModules.ps1 -Remove

# Scripted: no prompts.
./Install-AzureModules.ps1 -Remove -Section Graph,Teams
./Install-AzureModules.ps1 -Remove -Section All -Scope Both

# Preview.
./Install-AzureModules.ps1 -Remove -Section Legacy -WhatIf
```

The menu only lists sections that have something installed and marks cleanup-only sections. Without `-Section` and without an interactive console (for example `docker run` without `-it`), the script exits with code 2 rather than waiting for input.

## Parameters

| Parameter | Modes | Description |
|---|---|---|
| `-CoreOnly` | Install | Skip optional modules (Power BI on pwsh; Power Apps and MSCommerce on Windows PowerShell). |
| `-SkipUninstall` | Install | Install in place without removing existing versions first. Faster, but you may end up with more than one version. |
| `-ShowPlan` | Install | Print the plan and exit. |
| `-Report` | Report | Show installed state and exit. |
| `-Remove` | Remove | Remove modules by section. |
| `-Section` | Remove | One or more section names, or `All`. Comma-separated values work both inside PowerShell and from `pwsh -File`. |
| `-Scope` | Install, Remove | `CurrentUser` (default) or `AllUsers`; Remove also accepts `Both`. AllUsers and Both need elevation. |
| `-Repository` | Install | PSResourceGet repository to use. Defaults to `PSGallery`; point it at an internal mirror or local feed for offline or controlled builds. |
| `-WhatIf` | Install, Remove | Show what would be uninstalled or installed without doing it. |

## Sections

Used by `-Report`, the `-Remove` menu, and `-Section`. Each section belongs to exactly one profile, so removing a cleanup-only section never removes a module the host uses.

| Section | Modules | Installed on |
|---|---|---|
| `Azure` | Az (and all `Az.*`) | pwsh |
| `Graph` | Microsoft.Graph, Microsoft.Graph.Beta (and all `Microsoft.Graph*`) | pwsh |
| `Exchange` | ExchangeOnlineManagement | pwsh |
| `Teams` | MicrosoftTeams | pwsh |
| `SharePoint` | PnP.PowerShell | pwsh |
| `PowerBI` | MicrosoftPowerBIMgmt (and all `MicrosoftPowerBIMgmt.*`) | pwsh (optional) |
| `SPOClassic` | Microsoft.Online.SharePoint.PowerShell | Windows PowerShell |
| `PowerPlatform` | Microsoft.PowerApps.Administration.PowerShell, Microsoft.PowerApps.PowerShell | Windows PowerShell (optional) |
| `Commerce` | MSCommerce | Windows PowerShell (optional) |
| `Legacy` | AzureAD, AzureADPreview, MSOnline | Never (cleanup only) |

The `Microsoft.Graph*` pattern also matches any other module whose name starts with `Microsoft.Graph`.

## Scopes and what the script can and cannot remove

A module can be in three kinds of places:

| Where | Examples | Handled by |
|---|---|---|
| CurrentUser folder | `~/Documents/PowerShell/Modules`, `~/Documents/WindowsPowerShell/Modules`, `~/.local/share/powershell/Modules` | `-Scope CurrentUser` (default) |
| AllUsers folder | `C:\Program Files\PowerShell\Modules`, `C:\Program Files\WindowsPowerShell\Modules`, `/usr/local/share/powershell/Modules` | `-Scope AllUsers` or `-Scope Both`, elevated |
| Other | MSI installs (such as the SharePoint Online Management Shell installer), hand-copied folders, or modules in another host's folder | Reported only |

The script removes only what PowerShellGet or PSResourceGet installed in the host's own folders, including modules installed earlier with `Install-Module`. Copies in the **Other** column are listed with their path and the reason:

- **no package metadata**: uninstall with its installer if it has one, otherwise delete the folder.
- **outside this host's module folders**: for example, pwsh on Windows also loads modules from Windows PowerShell's folder. Run `-Remove` from the PowerShell that owns that folder.

The script never deletes these itself.

CurrentUser comes before AllUsers on the module path, so a CurrentUser copy loads instead of an AllUsers copy of the same module. The install summary warns when that applies.

## Running in a container

Containers usually run as root, so `-Scope AllUsers` works and makes the modules available to any user in the container.

```bash
pwsh -NoProfile -File ./Install-AzureModules.ps1 -Scope AllUsers
pwsh -NoProfile -File ./Install-AzureModules.ps1 -Report
pwsh -NoProfile -File ./Install-AzureModules.ps1 -Remove -Section All -Scope Both
```

The interactive menu needs a TTY (`docker run -it`). Use `-Section` for unattended runs. A non-zero exit code fails the build step.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success, or `-ShowPlan` / `-Report`, or nothing to do |
| 1 | A module failed to resolve, install, or uninstall cleanly; the repository is not registered; or PSResourceGet could not be set up |
| 2 | Unsupported PowerShell host, unknown `-Section` name, invalid `-Scope` for the mode, AllUsers scope without elevation, or `-Remove` with no `-Section` and no interactive console |

## Notes and limitations

- **"Latest" is not pinned across runs.** Within one run, every module installs the exact version found during lookup. A run next week can install newer versions. For fully pinned builds, point `-Repository` at a feed that holds the versions you want.
- **The full install is slow.** Microsoft.Graph and Microsoft.Graph.Beta together are well over a hundred modules, and a re-run removes and reinstalls them. `-CoreOnly` and `-SkipUninstall` shorten it.
- **Loaded modules can block removal on Windows.** Run from a fresh session (`pwsh -NoProfile` or `powershell.exe -NoProfile`) if the summary reports leftovers.
- **PnP.PowerShell needs your own Entra ID app registration** (`Register-PnPEntraIDApp`). The shared PnP Management Shell app no longer exists.
- **Trust is per call.** Installs use `-TrustRepository` rather than changing the repository's saved trust setting.
- **The file is plain ASCII on purpose.** Windows PowerShell 5.1 misreads UTF-8 files without a BOM, and characters like an em dash can break string parsing. Keep it ASCII if you edit it.
- **Run it as a script, not dot-sourced.** It uses `exit` to return status codes, which would close a dot-sourced session.
