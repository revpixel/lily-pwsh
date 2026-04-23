<#

.SYNOPSIS
    Installs and updates all required modern PowerShell modules for Microsoft 365,
    Azure, and Microsoft Graph administration in a clean, reproducible sandbox environment.

.DESCRIPTION
    This script prepares a sterile PowerShell environment by:
      - Trusting PSGallery (if not already trusted)
      - Checking for the latest versions of all required modules
      - Removing all previously installed versions to avoid version drift
      - Installing fresh copies of each module (GA + Beta + workload-specific)
      - Ensuring consistent module state across VM snapshots and rebuilds

    Modules covered include:
      - Az (Azure)
      - Microsoft Graph (GA, Beta, and workload-specific modules)
      - Exchange Online (EXO V3)
      - Microsoft Teams (PowerShell module)
      - SharePoint Online (PnP.PowerShell)

    Legacy modules such as AzureAD, AzureADPreview, and MSOnline have been removed.
    These modules are deprecated, unsupported in PowerShell 7, and scheduled for retirement.

    Intended for use in disposable or sandboxed environments where deterministic,
    repeatable module state is required for modern cloud administration work.

.NOTES
    This script may take several minutes to complete depending on module size and
    dependency chains.

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

Write-Host "Preparing modern sandbox environment..." -ForegroundColor Cyan

# Trust PSGallery
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Modern modules only — NO legacy
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

    # Teams (legacy module but still required)
    "MicrosoftTeams",

    # SharePoint Online (PnP)
    "PnP.PowerShell"
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

Write-Host "`nAll modern modules installed and updated." -ForegroundColor Green
Write-Host "`nReminder: Verify installed modules with:" -ForegroundColor Cyan
Write-Host "Get-InstalledModule | Sort-Object Name | Format-Table Name, Version" -ForegroundColor Yellow
