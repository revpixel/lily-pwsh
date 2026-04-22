## Purpose
This script installs and updates all required PowerShell modules for Microsoft 365, Azure, and Microsoft Graph administration in a clean, reproducible environment. It is designed for use in sandbox VMs where deterministic module state is critical for reliable cloud administration work.

## Where This Script Is Used
🧪 Sterile sandbox VMs
These are clean, identity‑free virtual machines used for:

Microsoft 365 and Azure administration

Graph API testing

Dev/test identities

Disposable experimentation

Client‑agnostic work where no tenant identity should be present

These VMs are intentionally isolated and rebuilt frequently. This script ensures the PowerShell module layer inside them is just as sterile and predictable as the VM itself.

## 🔐 Identity‑bound sandboxes
Some workflows require a VM that is joined to an Entra tenant — for example, when:

Conditional Access blocks Cloud Shell

Device compliance requires a registered or hybrid‑joined device

External or unmanaged devices cannot authenticate

You need to test behavior under real tenant policies

These identity‑bound sandboxes are still controlled environments, but they carry an Entra identity for testing or client‑specific operations. The script ensures the module stack in these VMs remains clean and consistent even when tenant policies are strict.

This is the same pattern used when building controlled environments like the one we set up for BNH — compliant, isolated, and predictable.

## Why This Script Exists
Microsoft’s module ecosystem is fragmented:

Graph has deep GA + Beta dependency trees

Azure has a wide, multi‑module dependency chain

PnP.PowerShell is large and slow to load

Legacy modules (AzureAD, AzureADPreview, MSOnline) are deprecated but still required in some tenants

Version drift between snapshots or rebuilds can cause unpredictable behavior.
This script eliminates that by enforcing a deterministic module baseline every time it runs.

## What the Script Does
**Module hygiene**
The script:
- Ensures PSGallery is trusted
- Checks each module against the latest version
- Removes all installed versions to avoid drift
- Installs fresh copies of each module
- Pulls in all dependencies cleanly
- Covers GA, Beta, and legacy modules

**Modules included**
- Az (Azure)
- Microsoft.Graph (full GA workloads)
- Microsoft.Graph.Beta (full Beta workloads)
- ExchangeOnlineManagement
- MicrosoftTeams (legacy)
- PnP.PowerShell

## Why It’s Slow — On Purpose
A full run takes 10–15 minutes, even when everything is already installed.
This is intentional.

The script is slow because it:

Enumerates every installed version

Uninstalls them

Resolves dependency trees

Reinstalls everything cleanly

Walks the entire Graph GA + Beta module set

Pulls Azure and PnP’s heavy dependency chains

This is the cost of reproducibility.
The payoff is a module environment that behaves the same way every time, regardless of VM rebuilds, snapshots, or tenant context.

## When to Use It
Use this script when you need:

A sterile, predictable PowerShell environment

A reproducible baseline across multiple VMs

A clean module stack for client tenant work

A compliant environment for tenants with strict CA/device policies

A safe place to run Graph, Azure, EXO, or legacy commands without polluting your main machine

## Summary
This script is part of a broader operational philosophy: clean baselines, deterministic environments, and predictable behavior across all your admin sandboxes.

Whether the VM is identity‑free or Entra‑joined, the goal is the same — eliminate drift, enforce consistency, and ensure every module behaves exactly as expected.

## Expected Warnings During a Normal Run
You may see warnings like:
```
WARNING: The version '1.4.8.1' of module 'PackageManagement' is currently in use.
WARNING: The version '2.2.5' of module 'PowerShellGet' is currently in use.
```
These are expected.

PowerShellGet and PackageManagement are core engine modules that load automatically when the session starts, so they cannot be removed or updated mid‑session. The script continues normally, and all other modules install cleanly.

These warnings can be safely ignored.
## Example Output
```
Preparing sandbox environment...

Processing Az...
Az: Already up to date (15.4.0)
Removing old versions of Az...
Installing/Updating Az...

Processing Microsoft.Graph...
Microsoft.Graph: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph...
Installing/Updating Microsoft.Graph...

Processing Microsoft.Graph.Beta...
Installing/Updating Microsoft.Graph.Beta...

Processing Microsoft.Graph.Authentication...
Microsoft.Graph.Authentication: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Authentication...
Installing/Updating Microsoft.Graph.Authentication...

Processing Microsoft.Graph.Identity.DirectoryManagement...
Microsoft.Graph.Identity.DirectoryManagement: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Identity.DirectoryManagement...
Installing/Updating Microsoft.Graph.Identity.DirectoryManagement...

Processing Microsoft.Graph.Identity.SignIns...
Microsoft.Graph.Identity.SignIns: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Identity.SignIns...
Installing/Updating Microsoft.Graph.Identity.SignIns...

Processing Microsoft.Graph.Security...
Microsoft.Graph.Security: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Security...
Installing/Updating Microsoft.Graph.Security...

Processing Microsoft.Graph.Reports...
Microsoft.Graph.Reports: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Reports...
Installing/Updating Microsoft.Graph.Reports...

Processing Microsoft.Graph.DeviceManagement...
Microsoft.Graph.DeviceManagement: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.DeviceManagement...
Installing/Updating Microsoft.Graph.DeviceManagement...

Processing Microsoft.Graph.Identity.Governance...
Microsoft.Graph.Identity.Governance: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Identity.Governance...
Installing/Updating Microsoft.Graph.Identity.Governance...

Processing Microsoft.Graph.Teams...
Microsoft.Graph.Teams: Already up to date (2.35.1)
Removing old versions of Microsoft.Graph.Teams...
Installing/Updating Microsoft.Graph.Teams...

Processing ExchangeOnlineManagement...
ExchangeOnlineManagement: Already up to date (3.9.2)
Removing old versions of ExchangeOnlineManagement...
Installing/Updating ExchangeOnlineManagement...
WARNING: The version '1.4.8.1' of module 'PackageManagement' is currently in use.
WARNING: The version '2.2.5' of module 'PowerShellGet' is currently in use.

Processing MicrosoftTeams...
MicrosoftTeams: Already up to date (7.6.0)
Removing old versions of MicrosoftTeams...
Installing/Updating MicrosoftTeams...

Processing PnP.PowerShell...
PnP.PowerShell: Already up to date (3.1.0)
Removing old versions of PnP.PowerShell...
Installing/Updating PnP.PowerShell...

Processing MSOnline...
MSOnline: Already up to date (1.1.183.81)
Removing old versions of MSOnline...
Installing/Updating MSOnline...

Processing AzureAD...
AzureAD: Already up to date (2.0.2.182)
Removing old versions of AzureAD...
Installing/Updating AzureAD...

Processing AzureADPreview...
AzureADPreview: Already up to date (2.0.2.183)
Removing old versions of AzureADPreview...
Installing/Updating AzureADPreview...

All requested modules installed and updated.
```


