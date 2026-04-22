<#

.SYNOPSIS
    Installs and updates all required PowerShell modules for Microsoft 365, Azure,
    and Microsoft Graph administration in a clean, reproducible sandbox environment.

.DESCRIPTION
    This script prepares a sterile PowerShell environment by:
      - Trusting PSGallery (if not already trusted)
      - Checking for the latest versions of all required modules
      - Removing all previously installed versions to avoid version drift
      - Installing fresh copies of each module (GA + Beta + legacy)
      - Ensuring consistent module state across VM snapshots and rebuilds

    Modules covered include:
      - Az (Azure)
      - Microsoft Graph (full GA + Beta workloads)
      - Exchange Online
      - Teams (legacy)
      - SharePoint Online (PnP)
      - Legacy AzureAD/MSOnline modules for compatibility

    Intended for use in disposable or sandboxed environments where deterministic,
    repeatable module state is required for cloud administration work.

.NOTES
    This script is intentionally slow. A full run typically takes 15+ minutes
    even on a fast system, especially when all modules are already installed.

    The slowness is by design:
      - Every module is checked against PSGallery for the latest version.
      - All previously installed versions are removed to prevent version drift.
      - Fresh copies are installed cleanly, including all dependencies.
      - Graph GA + Beta workloads have large dependency trees.
      - Azure and PnP modules often trigger additional submodule installs.

    The result is a fully deterministic, reproducible module environment suitable
    for sterile VM baselines, disposable sandboxes, and consistent cloud admin work.

#>

# Ensure TLS 1.2 for PSGallery
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Preparing sandbox environment..." -ForegroundColor Cyan

# Trust PSGallery
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Core + Graph + Beta + Legacy
$modules = @(
    # Azure
    "Az",

    # Microsoft Graph (full coverage)
    "Microsoft.Graph",
    "Microsoft.Graph.Beta",
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.Identity.SignIns",
    "Microsoft.Graph.Security",
    "Microsoft.Graph.Reports",
    "Microsoft.Graph.DeviceManagement",
    "Microsoft.Graph.Identity.Governance",
    "Microsoft.Graph.Teams",

    # Exchange Online
    "ExchangeOnlineManagement",

    # Teams (legacy)
    "MicrosoftTeams",

    # SharePoint Online
    "PnP.PowerShell",

    # Legacy modules (still needed for some tenants)
    "MSOnline",
    "AzureAD",
    "AzureADPreview"
)

foreach ($m in $modules) {

    Write-Host "`nProcessing ${m}..." -ForegroundColor Yellow

    # Check installed version
    $installed = Get-InstalledModule ${m} -ErrorAction SilentlyContinue
    $latest = Find-Module ${m} -Repository PSGallery -ErrorAction SilentlyContinue

    if ($installed -and $latest) {
        if ($installed.Version -lt $latest.Version) {
            Write-Host "${m}: Update available ($($installed.Version) → $($latest.Version))" -ForegroundColor Cyan
        } else {
            Write-Host "${m}: Already up to date ($($installed.Version))" -ForegroundColor DarkGreen
        }
    }

    # Remove old versions to keep sandbox sterile
    if ($installed) {
        Write-Host "Removing old versions of ${m}..." -ForegroundColor DarkCyan
        Get-InstalledModule ${m} -AllVersions -ErrorAction SilentlyContinue |
            Uninstall-Module -Force -ErrorAction SilentlyContinue
    }

    # Install or update module
    Write-Host "Installing/Updating ${m}..." -ForegroundColor Yellow
    try {
        Install-Module ${m} -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
    }
    catch {
        Write-Host "Initial install failed for ${m}. Retrying..." -ForegroundColor Red
        Start-Sleep -Seconds 2
        try {
            Install-Module ${m} -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
        }
        catch {
            Write-Host "Failed to install ${m} after retry: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nAll requested modules installed and updated." -ForegroundColor Green
