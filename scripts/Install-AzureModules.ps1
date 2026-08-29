<#
 
.SYNOPSIS
    Installs and updates all required modern PowerShell modules for Microsoft 365,
    Azure, and Microsoft Graph administration in a clean, reproducible sandbox environment.
 
.DESCRIPTION
    This script prepares a sterile PowerShell environment by:
      - Bootstrapping the NuGet provider and trusting PSGallery (if not already trusted)
      - Checking for the latest versions of all required modules
      - Removing all previously installed versions (including the sub-modules that ship
        inside the Az and Microsoft Graph "meta" packages) to avoid version drift
      - Installing fresh copies of each module (GA + Beta + workload-specific)
      - Ensuring consistent module state across VM snapshots and rebuilds
 
    Modules covered include:
      - Az (Azure — full umbrella, every Az.* service module)
      - Microsoft Graph (GA meta-module and Beta meta-module — pulls in every workload
        sub-module: Users, Groups, Mail, Files, Sites, DeviceManagement, Security, etc.)
      - Exchange Online & Security/Compliance (EXO V3)
      - Microsoft Teams (PowerShell module)
      - SharePoint Online — both PnP.PowerShell (modern) and the classic
        Microsoft.Online.SharePoint.PowerShell management shell
      - Power Platform, Power BI, and Microsoft 365 Apps admin modules (-IncludeExtras)
 
    Legacy modules such as AzureAD, AzureADPreview, and MSOnline are intentionally
    excluded. They are deprecated, unsupported in PowerShell 7, and scheduled for
    retirement.
 
    Intended for use in disposable or sandboxed environments where deterministic,
    repeatable module state is required for modern cloud administration work.
 
.PARAMETER IncludeExtras
    Also install Power Platform, Power BI, and Microsoft 365 Apps admin modules
    (Microsoft.PowerApps.Administration.PowerShell, Microsoft.PowerApps.PowerShell,
    MicrosoftPowerBIMgmt, MSCommerce). Included by default — pass -IncludeExtras:$false
    (or use -CoreOnly) if you only want the core Azure/Graph/EXO/Teams/SPO set.
 
.PARAMETER CoreOnly
    Skip the "extras" set above and only install the core module list.
 
.PARAMETER SkipUninstall
    Skip the uninstall-old-versions step and just install/update in place. Much faster,
    but the environment is no longer guaranteed to be a sterile single-version install.
 
.NOTES
    This script may take several minutes to complete depending on module size and
    dependency chains.
 
    The slowness is by design:
      - Every module is checked against PSGallery for the latest version.
      - All previously installed versions are removed to prevent version drift.
      - Fresh copies are installed cleanly, including all dependencies.
      - Graph GA + Beta workloads have large dependency trees.
      - Azure and PnP modules often trigger additional submodule installs.
 
    Known gotcha this script accounts for: Uninstall-Module on a "meta" package like
    Az or Microsoft.Graph only removes that thin wrapper module — it does NOT remove
    the 100+ Az.* / Microsoft.Graph.* sub-modules that were actually installed as
    dependencies. Left alone, that means the "sterile reinstall" step silently fails
    to achieve sterility for exactly the two biggest module families. This script
    explicitly sweeps and removes the whole family (Az.*, Microsoft.Graph.*) before
    reinstalling.
 
    The result is a fully deterministic, reproducible module environment suitable
    for sterile VM baselines, disposable sandboxes, and consistent cloud admin work.
 
#>
 
[CmdletBinding()]
param(
    [switch]$IncludeExtras = $true,
    [switch]$CoreOnly,
    [switch]$SkipUninstall
)
 
# Ensure TLS 1.2 for PSGallery
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
# Suppress the progress bar UI — this alone cuts Install-Module/Uninstall-Module
# time dramatically, since PowerShell's default progress rendering is very slow.
$ProgressPreference = 'SilentlyContinue'
 
Write-Host "Preparing modern sandbox environment..." -ForegroundColor Cyan
 
# --- Bootstrap package tooling -------------------------------------------------
 
# Make sure a modern NuGet provider is present; a bare/fresh machine often only has
# an old one, and Install-Module will otherwise stop to prompt for this.
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
    Write-Host "Installing NuGet package provider..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    Write-Warning "NuGet provider was just installed. If this is a brand-new machine and later steps fail, re-run this script in a fresh PowerShell session."
}
 
# Make sure PSGallery is registered at all before checking/setting its trust policy —
# on some minimal/Server Core images it isn't, and Get-PSRepository would otherwise
# throw a terminating error here.
if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSGallery repository..." -ForegroundColor Yellow
    Register-PSRepository -Default
}
 
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
 
# --- Module inventory ------------------------------------------------------------
# Note: Microsoft.Graph and Microsoft.Graph.Beta are "meta" modules whose manifests
# declare every workload sub-module (Users, Groups, Mail, Files, Sites, Security,
# DeviceManagement, Identity.Governance, Teams, Planner, ...) as a required dependency.
# Installing the two meta-modules already gives full Graph coverage, so we don't also
# list the individual sub-modules — doing so was redundant in the original script and
# just caused extra install/uninstall churn for modules that were already satisfied.
 
$coreModules = @(
    # Azure — full umbrella, every Az.* service module
    "Az",
 
    # Microsoft Graph — GA and Beta, full workload coverage via meta-modules
    "Microsoft.Graph",
    "Microsoft.Graph.Beta",
 
    # Exchange Online (EXO V3) — also covers Security & Compliance (IPPSSession)
    "ExchangeOnlineManagement",
 
    # Microsoft Teams
    "MicrosoftTeams",
 
    # SharePoint Online — modern (PnP) and classic management shell
    "PnP.PowerShell",
    "Microsoft.Online.SharePoint.PowerShell"
)
 
$extraModules = @(
    # Power Platform admin + maker cmdlets
    "Microsoft.PowerApps.Administration.PowerShell",
    "Microsoft.PowerApps.PowerShell",
 
    # Power BI tenant administration
    "MicrosoftPowerBIMgmt",
 
    # Microsoft 365 Apps / self-service purchase admin
    "MSCommerce"
)
 
$modules = $coreModules
if ($IncludeExtras -and -not $CoreOnly) {
    $modules += $extraModules
}
 
# Meta-packages whose installed footprint extends beyond their own module name and
# needs a wildcard sweep to actually come out sterile.
$metaFamilies = @{
    "Az"               = "Az.*"
    "Microsoft.Graph"  = "Microsoft.Graph*"   # also sweeps Microsoft.Graph.Beta.*
}
 
function Uninstall-ModuleFamily {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$WildcardPattern
    )
 
    $targets = @(Get-InstalledModule -Name $Name -ErrorAction SilentlyContinue)
    if ($WildcardPattern) {
        $targets += @(Get-InstalledModule -Name $WildcardPattern -ErrorAction SilentlyContinue)
    }
    $targets = $targets | Sort-Object Name -Unique
 
    if (-not $targets) { return }
 
    Write-Host "Removing $($targets.Count) installed module(s) in the '$Name' family..." -ForegroundColor DarkCyan
 
    # PowerShellGet refuses to remove a module that's still a dependency of another
    # installed module, so sweep a few passes: each pass clears whatever no longer
    # has a dependent, until nothing more can be removed.
    for ($pass = 1; $pass -le 4; $pass++) {
        $remaining = @(Get-InstalledModule -Name $Name -ErrorAction SilentlyContinue)
        if ($WildcardPattern) {
            $remaining += @(Get-InstalledModule -Name $WildcardPattern -ErrorAction SilentlyContinue)
        }
        $remaining = $remaining | Sort-Object Name -Unique
        if (-not $remaining) { break }
 
        foreach ($mod in $remaining) {
            Get-InstalledModule -Name $mod.Name -AllVersions -ErrorAction SilentlyContinue |
                Uninstall-Module -Force -ErrorAction SilentlyContinue
        }
    }
}
 
# --- Main install loop -------------------------------------------------------------
 
$results = [System.Collections.Generic.List[pscustomobject]]::new()
 
foreach ($m in $modules) {
 
    Write-Host "`nProcessing ${m}..." -ForegroundColor Yellow
 
    $installed = Get-InstalledModule $m -ErrorAction SilentlyContinue
    $latest = Find-Module $m -Repository PSGallery -ErrorAction SilentlyContinue
 
    if (-not $latest) {
        Write-Host "${m}: Not found on PSGallery — skipping." -ForegroundColor Red
        $results.Add([pscustomobject]@{ Module = $m; Status = "NotFound"; Notes = "Not found on PSGallery" })
        continue
    }
 
    if ($installed) {
        if ($installed.Version -lt $latest.Version) {
            Write-Host "${m}: Update available ($($installed.Version) -> $($latest.Version))" -ForegroundColor Cyan
        } else {
            Write-Host "${m}: Already up to date ($($installed.Version))" -ForegroundColor DarkGreen
        }
    }
 
    if (-not $SkipUninstall) {
        if ($metaFamilies.ContainsKey($m)) {
            Uninstall-ModuleFamily -Name $m -WildcardPattern $metaFamilies[$m]
        } elseif ($installed) {
            Write-Host "Removing old versions of ${m}..." -ForegroundColor DarkCyan
            Get-InstalledModule $m -AllVersions -ErrorAction SilentlyContinue |
                Uninstall-Module -Force -ErrorAction SilentlyContinue
        }
    }
 
    Write-Host "Installing/Updating ${m}..." -ForegroundColor Yellow
    $status = "Failed"
    $notes = ""
    try {
        Install-Module $m -Scope CurrentUser -Force -AllowClobber -AcceptLicense -Repository PSGallery -ErrorAction Stop
        $status = "Success"
    }
    catch {
        Write-Host "Initial install failed for ${m}. Retrying..." -ForegroundColor Red
        Start-Sleep -Seconds 2
        try {
            Install-Module $m -Scope CurrentUser -Force -AllowClobber -AcceptLicense -Repository PSGallery -ErrorAction Stop
            $status = "Success (after retry)"
        }
        catch {
            Write-Host "Failed to install ${m} after retry: $_" -ForegroundColor Red
            $notes = $_.Exception.Message
        }
    }
 
    $results.Add([pscustomobject]@{ Module = $m; Status = $status; Notes = $notes })
}
 
# --- Summary -------------------------------------------------------------------
 
Write-Host "`n===== Install Summary =====" -ForegroundColor Cyan
$results | Format-Table -AutoSize
 
$failed = $results | Where-Object { $_.Status -notlike "Success*" }
if ($failed) {
    Write-Host "$($failed.Count) module(s) did not install cleanly — see table above." -ForegroundColor Red
} else {
    Write-Host "All modules installed and updated successfully." -ForegroundColor Green
}
 
if ($PSVersionTable.PSEdition -eq 'Core' -and $modules -contains 'Microsoft.Online.SharePoint.PowerShell') {
    Write-Warning "Microsoft.Online.SharePoint.PowerShell has limited PowerShell 7 (Core) support. If cmdlets fail to load, import it via: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell"
}
 
Write-Host "`nReminder: Verify installed modules with:" -ForegroundColor Cyan
Write-Host "Get-InstalledModule | Sort-Object Name | Format-Table Name, Version" -ForegroundColor Yellow
