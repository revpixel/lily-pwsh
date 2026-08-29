## 📝 Purpose
This script installs and updates all required PowerShell modules for Microsoft 365, Azure, and Microsoft Graph administration in a clean, reproducible environment. It is designed for use in sandbox VMs where deterministic module state is critical for reliable cloud administration work.

## 🧭 Where This Script Is Used
🧪 **Sterile sandbox VMs**
These are clean, identity‑free virtual machines used for:

- Microsoft 365 and Azure administration
- Graph API testing
- Dev/test identities
- Disposable experimentation
- Client‑agnostic work where no tenant identity should be present

These VMs are intentionally isolated and rebuilt frequently. This script ensures the PowerShell module layer inside them is just as sterile and predictable as the VM itself.

## 🔐 Identity‑bound sandboxes
Some workflows require a VM that is joined to an Entra tenant — for example, when:

- Conditional Access blocks Cloud Shell
- Device compliance requires a registered or hybrid‑joined device
- External or unmanaged devices cannot authenticate
- You need to test behavior under real tenant policies
- These identity‑bound sandboxes are still controlled environments, but they carry an Entra identity for testing or client‑specific operations. The script ensures the module stack in these VMs remains clean and consistent even when tenant policies are strict.
- This is the same pattern used when building controlled environments — compliant, isolated, and predictable.

## 🧩 Why This Script Exists
Microsoft’s module ecosystem is fragmented:

- Graph has deep GA + Beta dependency trees
- Azure has a wide, multi‑module dependency chain
- PnP.PowerShell is large and slow to load

Legacy modules (AzureAD, AzureADPreview, MSOnline) are deprecated but still required in some tenants

Version drift between snapshots or rebuilds can cause unpredictable behavior.
This script eliminates that by enforcing a deterministic module baseline every time it runs.

## ⚙️ What the Script Does

### Module hygiene
This script enforces a clean, deterministic module environment by:

- Ensuring PSGallery is trusted
- Checking each module against the latest available version
- Removing all installed versions to prevent drift
- Installing fresh copies of each module
- Pulling in all dependencies cleanly
- Guaranteeing consistent results across rebuilds and containers

### Modules included (Modern + Workloads)

- **Az** (Azure Resource Manager)
- **Microsoft.Graph** (GA)
- **Microsoft.Graph.Beta** (Beta)
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
- **MicrosoftTeams**
- **PnP.PowerShell**

### Legacy modules removed
The following deprecated modules are intentionally excluded:

- AzureAD  
- AzureADPreview  
- MSOnline  

These modules are not supported in PowerShell 7 and are scheduled for retirement.

### Why this matters
The script ensures:

- zero‑drift module baselines  
- reproducible environments  
- clean dependency trees  
- predictable behavior in containers and VMs  

This keeps the environment **sterile** and fully aligned with modern Microsoft 365 administration.


## ⏳ Why It’s Slow — On Purpose
A full run takes 10–15 minutes, even when everything is already installed.

- This is intentional.
- The script is slow because it:
- Enumerates every installed version
- Uninstalls them
- Resolves dependency trees
- Reinstalls everything cleanly
- Walks the entire Graph GA + Beta module set
- Pulls Azure and PnP’s heavy dependency chains

This is the cost of reproducibility.

The payoff is a module environment that behaves the same way every time, regardless of VM rebuilds, snapshots, or tenant context.

## 🎯 When to Use It
Use this script when you need:

- A sterile, predictable PowerShell environment
- A reproducible baseline across multiple VMs
- A clean module stack for client tenant work
- A compliant environment for tenants with strict CA/device policies
- A safe place to run Graph, Azure, EXO, or legacy commands without polluting your main machine

## 📌 Summary
This script is part of a broader operational philosophy: clean baselines, deterministic environments, and predictable behavior across all your admin sandboxes.

Whether the VM is identity‑free or Entra‑joined, the goal is the same — eliminate drift, enforce consistency, and ensure every module behaves exactly as expected.

## ▶️ Running This Script Outside a Sandbox VM
If you’re using this script standalone — not inside a sterile VM or container — your local PowerShell execution policy may block it.
You can temporarily bypass policy for this session only:
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./Install-AzureModules.ps1
```

## 📄 Example Output
> This example shows a *normal* module installation run.  
> Some modules (like Microsoft.Graph) install multiple workload submodules as dependencies.  
> On subsequent passes, those submodules may report “Already up to date” before being removed  
> and reinstalled cleanly. This is expected behavior and ensures a zero‑drift module baseline.
```
PowerShell 7.6.1
PS /> ./mnt/repo-scripts/Install-AzureModules.ps1
Preparing modern sandbox environment...

Processing Az...
Installing/Updating Az...

Processing Microsoft.Graph...
Installing/Updating Microsoft.Graph...

Processing Microsoft.Graph.Beta...
Installing/Updating Microsoft.Graph.Beta...

Processing Microsoft.Graph.Authentication...
Microsoft.Graph.Authentication: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Authentication...
Installing/Updating Microsoft.Graph.Authentication...

Processing Microsoft.Graph.Identity.DirectoryManagement...
Microsoft.Graph.Identity.DirectoryManagement: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Identity.DirectoryManagement...
Installing/Updating Microsoft.Graph.Identity.DirectoryManagement...

Processing Microsoft.Graph.Identity.SignIns...
Microsoft.Graph.Identity.SignIns: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Identity.SignIns...
Installing/Updating Microsoft.Graph.Identity.SignIns...

Processing Microsoft.Graph.Security...
Microsoft.Graph.Security: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Security...
Installing/Updating Microsoft.Graph.Security...

Processing Microsoft.Graph.Reports...
Microsoft.Graph.Reports: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Reports...
Installing/Updating Microsoft.Graph.Reports...

Processing Microsoft.Graph.DeviceManagement...
Microsoft.Graph.DeviceManagement: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.DeviceManagement...
Installing/Updating Microsoft.Graph.DeviceManagement...

Processing Microsoft.Graph.Identity.Governance...
Microsoft.Graph.Identity.Governance: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Identity.Governance...
Installing/Updating Microsoft.Graph.Identity.Governance...

Processing Microsoft.Graph.Teams...
Microsoft.Graph.Teams: Already up to date (2.36.1)
Removing old versions of Microsoft.Graph.Teams...
Installing/Updating Microsoft.Graph.Teams...

Processing ExchangeOnlineManagement...
Installing/Updating ExchangeOnlineManagement...

Processing MicrosoftTeams...
Installing/Updating MicrosoftTeams...

Processing PnP.PowerShell...
Installing/Updating PnP.PowerShell...

All modern modules installed and updated.
Reminder: Verify installed modules with:
Get-InstalledModule | Sort-Object Name | Format-Table Name, Version

PS />
```
> The script prints a reminder to list installed modules if you want to verify the final state. 
