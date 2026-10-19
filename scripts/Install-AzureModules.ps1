<#
.SYNOPSIS
    Installs, reports on, or removes the Microsoft 365 / Azure / Microsoft Graph
    admin modules that belong to the PowerShell host the script is run from.

.DESCRIPTION
    The script detects one of three host profiles and works only with the
    modules that belong to that host:

      WinPS        Windows PowerShell 5.1 (Desktop edition)
                   ONLY the modules that require Windows PowerShell:
                   classic SharePoint Online Management Shell, and (unless
                   -CoreOnly) Power Apps admin/maker modules and MSCommerce.

      PwshWindows  PowerShell 7.x on Windows
      PwshLinux    PowerShell 7.x on Linux (macOS falls into this profile too)
                   The cross-platform modern set: Az, Microsoft Graph (GA + Beta),
                   Exchange Online (EXO V3), Microsoft Teams, PnP.PowerShell, and
                   (unless -CoreOnly) Power BI.

    Any other host is refused: PowerShell 6.x, PowerShell 7 below the minimum
    minor version, a future major version, or Windows PowerShell older than 5.1.

    The two pwsh profiles currently get the same module set. They are kept as
    separate profiles so platform-specific modules can be added to one without
    touching the other.

    All package operations use PSResourceGet (Microsoft.PowerShell.PSResourceGet).
    It ships with PowerShell 7.4+; on Windows PowerShell 5.1 the script installs
    it on first run. PSResourceGet also sees modules installed earlier with
    PowerShellGet v2 (Install-Module), so -Report and -Remove cover those too.

    Modes (pick one):

      (default)    Install. Resolve every planned module first; if ANY lookup
                   fails, abort BEFORE uninstalling anything. Then sweep all
                   installed versions (including meta-package sub-modules such
                   as Az.* and Microsoft.Graph*), install the resolved versions,
                   verify, and print a summary.

      -ShowPlan    Print the host profile and planned modules. Changes nothing.

      -Report      Show what is currently installed, limited to the modules in
                   this script's catalog, grouped by section. Includes
                   cleanup-only modules (see below). Offline; changes nothing.

      -Remove      Uninstall modules this script manages, by section. Without
                   -Section you get a numbered menu (Enter = ALL). With
                   -Section the removal runs without prompts, for scripts and
                   containers. Supports -WhatIf.

    Cleanup-only modules: every catalog module is known on every host. Where
    its profile does not match, it is never installed, but -Report lists it
    and -Remove removes it. That catches, for example, an old Microsoft.Graph
    install in Windows PowerShell's module folder. The Legacy section
    (AzureAD, AzureADPreview, MSOnline) is cleanup-only everywhere: those
    modules are deprecated and are never installed.

.PARAMETER CoreOnly
    Install mode: skip the optional modules (Power BI on pwsh; Power Apps and
    MSCommerce on Windows PowerShell).

.PARAMETER SkipUninstall
    Install mode: skip the sweep and install in place. Faster, but the
    environment is no longer guaranteed to be a single-version install.

.PARAMETER ShowPlan
    Print the detected host profile and the modules that would be installed,
    then exit without changing anything.

.PARAMETER Report
    Report which managed modules are installed, their versions, scope, and
    sub-module counts, then exit without changing anything.

.PARAMETER Remove
    Remove managed modules. Prompts for sections unless -Section is given.

.PARAMETER Section
    Remove mode: one or more sections to remove without prompting, or All.
    Sections that do not belong to this host are skipped with a warning.

.PARAMETER Scope
    Which module scope to install into or remove from.
      CurrentUser  (default) the per-user module folder; no elevation needed.
      AllUsers     the machine-wide module folder, e.g.
                   C:\Program Files\WindowsPowerShell\Modules (WinPS),
                   C:\Program Files\PowerShell\Modules (pwsh on Windows),
                   /usr/local/share/powershell/Modules (Linux). Needs an
                   elevated session (Administrator, or root on Linux). In a
                   container image this makes the modules visible to any user.
      Both         Remove mode only: clean both scopes.
    -Report always shows both scopes, plus an "Other" column for copies the
    script cannot remove from this host: modules with no package metadata (MSI
    installers, copied folders) and modules sitting in another host's folder
    (e.g. Windows PowerShell's folder, which pwsh on Windows also loads). The
    script never deletes those; it tells you where they are and why.

.PARAMETER Repository
    PSResourceGet repository to resolve and install from. Defaults to PSGallery.
    Point it at an internal mirror or a local feed for offline or pinned builds.

.EXAMPLE
    pwsh ./Install-AzureModules.ps1
    Install everything for this host.

.EXAMPLE
    pwsh ./Install-AzureModules.ps1 -Report

.EXAMPLE
    pwsh ./Install-AzureModules.ps1 -Remove
    Shows the section menu; press Enter to remove everything.

.EXAMPLE
    pwsh ./Install-AzureModules.ps1 -Remove -Section Graph,Teams -WhatIf

.EXAMPLE
    powershell.exe -File .\Install-AzureModules.ps1 -Remove -Scope Both
    From an elevated Windows PowerShell: clean per-user and machine-wide copies.

.NOTES
    Exit codes:
      0  success (or -ShowPlan / -Report, or nothing to do)
      1  one or more modules failed to resolve, install, or uninstall cleanly
      2  unsupported PowerShell host, unknown -Section name, invalid -Scope
         for the mode, AllUsers scope without elevation, or -Remove with no
         -Section and no interactive console

    Windows PowerShell 5.1 needs .NET Framework 4.7.2 or later for PSResourceGet.

    This file is intentionally pure ASCII. Windows PowerShell 5.1 reads UTF-8
    files without a BOM as ANSI, and characters such as an em dash decode to a
    curly quote that breaks string parsing.

    Run it as a script (pwsh ./Install-AzureModules.ps1), not dot-sourced; it
    uses 'exit' to return status codes.
#>

[CmdletBinding(DefaultParameterSetName = 'Install', SupportsShouldProcess = $true)]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$CoreOnly,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$SkipUninstall,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$ShowPlan,

    [Parameter(ParameterSetName = 'Report', Mandatory = $true)]
    [switch]$Report,

    [Parameter(ParameterSetName = 'Remove', Mandatory = $true)]
    [switch]$Remove,

    # Validated below rather than with ValidateSet: 'pwsh -File script.ps1
    # -Section Graph,Teams' (Docker CMD, bash) passes one comma-joined string.
    [Parameter(ParameterSetName = 'Remove')]
    [string[]]$Section,

    # Install: CurrentUser or AllUsers. Remove: CurrentUser, AllUsers or Both.
    # AllUsers / Both need an elevated session (Administrator, or root on Linux).
    [Parameter(ParameterSetName = 'Install')]
    [Parameter(ParameterSetName = 'Remove')]
    [ValidateSet('CurrentUser', 'AllUsers', 'Both')]
    [string]$Scope = 'CurrentUser',

    [Parameter(ParameterSetName = 'Install')]
    [string]$Repository = 'PSGallery'
)

$ProgressPreference = 'SilentlyContinue'
$mode = $PSCmdlet.ParameterSetName

$validSections = @('All', 'Azure', 'Graph', 'Exchange', 'Teams', 'SharePoint', 'PowerBI', 'SPOClassic', 'PowerPlatform', 'Commerce', 'Legacy')
if ($Section) {
    $Section = @($Section | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
    $unknown = @($Section | Where-Object { $validSections -notcontains $_ })
    if ($unknown.Count -gt 0) {
        Write-Host ('Unknown section(s): {0}. Valid: {1}' -f ($unknown -join ', '), ($validSections -join ', ')) -ForegroundColor Red
        exit 2
    }
    # Normalize casing to the canonical names.
    $Section = @($Section | ForEach-Object { $s = $_; $validSections | Where-Object { $_ -ieq $s } } | Select-Object -Unique)
}

# --- Host policy -----------------------------------------------------------------
# pwsh is locked to major version 7. The minimum minor version is 7.4 because
# current PnP.PowerShell releases require it, and 7.4 is the first LTS that
# ships PSResourceGet in the box.

$PwshMajor    = 7
$PwshMinimum  = [version]'7.4'
$WinPSMinimum = [version]'5.1'

function Get-HostProfile {
    $v = $PSVersionTable.PSVersion
    $shortVersion = [version]('{0}.{1}' -f $v.Major, $v.Minor)

    # PSEdition is 'Desktop' on Windows PowerShell 5.1 and absent on 5.0 and earlier.
    if ($PSVersionTable.PSEdition -ne 'Core') {
        if ($shortVersion -lt $WinPSMinimum) { return $null }
        return 'WinPS'
    }

    if ($v.Major -ne $PwshMajor -or $shortVersion -lt $PwshMinimum) { return $null }
    if ($IsWindows) { return 'PwshWindows' }
    return 'PwshLinux'
}

# --- Module catalog ----------------------------------------------------------------
# Section  : group used by -Report and -Remove (also the -Section values).
#            Keep each section to modules of ONE profile, so removing a
#            cleanup-only section never takes modules this host uses.
# Profiles : which host profiles INSTALL this module. On every other host the
#            module is cleanup-only: never installed there, but -Report lists
#            it and -Remove removes it if a copy turns up (for example an old
#            Microsoft.Graph install in Windows PowerShell's module folder).
# Family   : extra wildcard(s) for meta packages whose sub-modules must be
#            swept/reported along with the main module
# Optional : skipped by -CoreOnly
#
# Note: 'Microsoft.Graph*' covers GA, Beta and Microsoft.Graph.Authentication
# together, which is why GA and Beta share one section. It will also catch any
# other module you have installed whose name starts with Microsoft.Graph.

$pwsh  = @('PwshWindows', 'PwshLinux')
$winps = @('WinPS')

$catalog = @(
    # Azure - full umbrella, every Az.* service module
    [pscustomobject]@{ Section = 'Azure';    Name = 'Az';                       Profiles = $pwsh; Family = @('Az.*');             Optional = $false }

    # Microsoft Graph - GA and Beta meta modules (full workload coverage)
    [pscustomobject]@{ Section = 'Graph';    Name = 'Microsoft.Graph';          Profiles = $pwsh; Family = @('Microsoft.Graph*'); Optional = $false }
    [pscustomobject]@{ Section = 'Graph';    Name = 'Microsoft.Graph.Beta';     Profiles = $pwsh; Family = @('Microsoft.Graph*'); Optional = $false }

    # Exchange Online V3 - also covers Security & Compliance (Connect-IPPSSession)
    [pscustomobject]@{ Section = 'Exchange'; Name = 'ExchangeOnlineManagement'; Profiles = $pwsh; Family = @();                   Optional = $false }

    # Microsoft Teams
    [pscustomobject]@{ Section = 'Teams';    Name = 'MicrosoftTeams';           Profiles = $pwsh; Family = @();                   Optional = $false }

    # SharePoint Online, modern. Requires your own Entra app registration
    # (Register-PnPEntraIDApp); the shared PnP Management Shell app is gone.
    [pscustomobject]@{ Section = 'SharePoint'; Name = 'PnP.PowerShell';         Profiles = $pwsh; Family = @();                   Optional = $false }

    # Power BI tenant administration (meta module with MicrosoftPowerBIMgmt.* sub-modules)
    [pscustomobject]@{ Section = 'PowerBI';  Name = 'MicrosoftPowerBIMgmt';     Profiles = $pwsh; Family = @('MicrosoftPowerBIMgmt.*'); Optional = $true }

    # --- Windows PowerShell 5.1 only ---

    # SharePoint Online classic management shell (not supported natively on pwsh)
    [pscustomobject]@{ Section = 'SPOClassic';    Name = 'Microsoft.Online.SharePoint.PowerShell';        Profiles = $winps; Family = @(); Optional = $false }

    # Power Platform admin + maker cmdlets
    [pscustomobject]@{ Section = 'PowerPlatform'; Name = 'Microsoft.PowerApps.Administration.PowerShell'; Profiles = $winps; Family = @(); Optional = $true }
    [pscustomobject]@{ Section = 'PowerPlatform'; Name = 'Microsoft.PowerApps.PowerShell';                Profiles = $winps; Family = @(); Optional = $true }

    # Microsoft 365 self-service purchase admin
    [pscustomobject]@{ Section = 'Commerce';      Name = 'MSCommerce';                                    Profiles = $winps; Family = @(); Optional = $true }

    # --- Legacy: never installed anywhere, cleanup-only on every host ---
    # Deprecated and retired in favor of Microsoft Graph PowerShell.
    [pscustomobject]@{ Section = 'Legacy'; Name = 'AzureAD';        Profiles = @(); Family = @(); Optional = $false }
    [pscustomobject]@{ Section = 'Legacy'; Name = 'AzureADPreview'; Profiles = @(); Family = @(); Optional = $false }
    [pscustomobject]@{ Section = 'Legacy'; Name = 'MSOnline';       Profiles = @(); Family = @(); Optional = $false }
)

# Display order and labels for sections.
$sectionOrder = @('Azure', 'Graph', 'Exchange', 'Teams', 'SharePoint', 'PowerBI', 'SPOClassic', 'PowerPlatform', 'Commerce', 'Legacy')
$sectionLabel = @{
    Azure         = 'Azure (Az)'
    Graph         = 'Microsoft Graph (GA + Beta)'
    Exchange      = 'Exchange Online'
    Teams         = 'Microsoft Teams'
    SharePoint    = 'SharePoint Online (PnP)'
    SPOClassic    = 'SharePoint Online (classic shell)'
    PowerBI       = 'Power BI'
    PowerPlatform = 'Power Platform'
    Commerce      = 'M365 Commerce'
    Legacy        = 'Legacy (AzureAD, MSOnline)'
}

# --- Helpers ---------------------------------------------------------------------

function Format-ResourceVersion {
    param($Resource)
    $text = [string]$Resource.Version
    if ($Resource.Prerelease) { $text = '{0}-{1}' -f $text, $Resource.Prerelease }
    $text
}

function Get-PatternsFor {
    # All name patterns (main module names plus family wildcards) for a set of catalog items.
    param([object[]]$Items)
    @($Items | ForEach-Object { $_.Name; $_.Family } | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-Installed {
    # Every installed version matching any of $Patterns in one scope, de-duplicated.
    param(
        [string[]]$Patterns,
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )
    $seen = @{}
    foreach ($p in $Patterns) {
        foreach ($r in @(Get-InstalledPSResource -Name $p -Scope $Scope -ErrorAction SilentlyContinue)) {
            $key = '{0}|{1}' -f $r.Name, (Format-ResourceVersion $r)
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $r }
        }
    }
    @($seen.Values | Sort-Object Name, Version)
}

function Remove-ModuleSet {
    # Uninstall every installed version of every module matching $Patterns in
    # one scope. -SkipDependencyCheck lets the whole family go in one pass
    # regardless of dependency order; extra passes are a safety net.
    # Returns the module versions that could not be removed.
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string[]]$Patterns,
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser'
    )

    $initial = @(Get-Installed -Patterns $Patterns -Scope $Scope)
    if ($initial.Count -eq 0) { return }

    $target = '{0} module version(s) in {1} scope' -f $initial.Count, $Scope
    if (-not $PSCmdlet.ShouldProcess($target, 'Uninstall-PSResource')) { return }

    for ($pass = 1; $pass -le 3; $pass++) {
        $remaining = @(Get-Installed -Patterns $Patterns -Scope $Scope)
        if ($remaining.Count -eq 0) { break }
        Write-Host ('  {0} pass {1}: removing {2} module version(s)' -f $Scope, $pass, $remaining.Count) -ForegroundColor DarkCyan
        foreach ($r in $remaining) {
            $exact = '[{0}]' -f (Format-ResourceVersion $r)
            try {
                Uninstall-PSResource -Name $r.Name -Version $exact -Scope $Scope -SkipDependencyCheck `
                    -ErrorAction Stop -WhatIf:$false -Confirm:$false
            }
            catch {
                Write-Verbose ('Could not remove {0} {1}: {2}' -f $r.Name, $exact, $_.Exception.Message)
            }
        }
    }

    Get-Installed -Patterns $Patterns -Scope $Scope
}

function Test-Elevated {
    # Administrator on Windows, root elsewhere.
    if ($hostProfile -eq 'PwshLinux') {
        return ((& id -u) -eq '0')
    }
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ModuleRoots {
    # The CurrentUser and AllUsers module folders that THIS host's package
    # manager installs into. Windows PowerShell and pwsh use different folders.
    $docs = [Environment]::GetFolderPath('MyDocuments')
    switch ($hostProfile) {
        'WinPS' {
            return @{
                CurrentUser = Join-Path $docs 'WindowsPowerShell\Modules'
                AllUsers    = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
            }
        }
        'PwshWindows' {
            return @{
                CurrentUser = Join-Path $docs 'PowerShell\Modules'
                AllUsers    = Join-Path $env:ProgramFiles 'PowerShell\Modules'
            }
        }
        default {
            $dataHome = $env:XDG_DATA_HOME
            if (-not $dataHome) { $dataHome = Join-Path $HOME '.local/share' }
            return @{
                CurrentUser = Join-Path $dataHome 'powershell/Modules'
                AllUsers    = '/usr/local/share/powershell/Modules'
            }
        }
    }
}

function Test-UnderPath {
    param([string]$Path, [string]$Root)
    $sep = [IO.Path]::DirectorySeparatorChar
    $r = $Root.TrimEnd('\', '/') + $sep
    $comparison = [StringComparison]::Ordinal
    if ($hostProfile -ne 'PwshLinux') { $comparison = [StringComparison]::OrdinalIgnoreCase }
    $Path.StartsWith($r, $comparison)
}

function Get-OtherCopies {
    # Copies of matching modules that load on this host but that this script
    # cannot remove with Uninstall-PSResource:
    #   - no package metadata: MSI installs (e.g. the SharePoint Online
    #     Management Shell installer), folders copied by hand, bundled modules.
    #     PowerShellGet v2 and PSResourceGet both drop PSGetModuleInfo.xml into
    #     every version folder they install; these have none.
    #   - outside this host's module folders: e.g. a module in Windows
    #     PowerShell's folder that pwsh on Windows also loads. Remove those
    #     from the host that owns that folder.
    param([string[]]$Patterns)
    $roots = Get-ModuleRoots
    $seen = @{}
    foreach ($p in $Patterns) {
        foreach ($m in @(Get-Module -ListAvailable -Name $p -ErrorAction SilentlyContinue)) {
            $base = $m.ModuleBase
            if ($seen.ContainsKey($base)) { continue }

            $hasMeta = Test-Path -LiteralPath (Join-Path $base 'PSGetModuleInfo.xml')
            $inOwnRoot = (Test-UnderPath -Path $base -Root $roots.CurrentUser) -or
                         (Test-UnderPath -Path $base -Root $roots.AllUsers)
            if ($hasMeta -and $inOwnRoot) { continue }   # tracked; handled by the scope columns

            $reason = 'no package metadata'
            if ($hasMeta) { $reason = 'outside this host''s module folders' }
            $seen[$base] = [pscustomobject]@{
                Name    = $m.Name
                Version = [string]$m.Version
                Path    = $base
                Reason  = $reason
            }
        }
    }
    @($seen.Values | Sort-Object Name, Version)
}

function Write-OtherWarning {
    param([object[]]$Copies)
    if (-not $Copies -or $Copies.Count -eq 0) { return }
    Write-Warning ('{0} module copy(ies) can load on this host but cannot be removed from here:' -f $Copies.Count)
    foreach ($c in $Copies) {
        Write-Host ('    {0} {1}  [{2}]  {3}' -f $c.Name, $c.Version, $c.Reason, $c.Path) -ForegroundColor Yellow
    }
    Write-Host '    No package metadata: uninstall via its installer (Settings > Apps) if it has one, otherwise delete the folder.' -ForegroundColor Yellow
    Write-Host '    Outside this host''s folders: run -Remove from the PowerShell that owns that folder (powershell.exe vs pwsh).' -ForegroundColor Yellow
}

function Write-LoadedWarning {
    # Loaded modules hold file locks on Windows and can block uninstall.
    param([string[]]$Patterns)
    $loaded = @(foreach ($p in $Patterns) { Get-Module -Name $p })
    if ($loaded.Count -gt 0) {
        Write-Warning ('Modules are loaded in this session and may not uninstall cleanly: {0}. Run from a fresh session (pwsh -NoProfile) if anything is left behind.' -f (($loaded.Name | Sort-Object -Unique) -join ', '))
    }
}

function Write-Table {
    # Format-Table output and Write-Host can interleave out of order in scripts;
    # render the table to a string so it prints exactly where it is called.
    param([object[]]$Rows, [string[]]$Property)
    if (-not $Rows -or $Rows.Count -eq 0) { return }
    $text = ($Rows | Format-Table -Property $Property -AutoSize | Out-String -Width 250).TrimEnd()
    Write-Host $text
}

function Initialize-PSResourceGet {
    # Make sure PSResourceGet is importable. pwsh 7.4+ ships it; Windows
    # PowerShell 5.1 needs it installed once (via the built-in PowerShellGet v1).
    if (-not (Get-Module -Name Microsoft.PowerShell.PSResourceGet -ListAvailable)) {
        if ($hostProfile -ne 'WinPS') {
            Write-Host 'Microsoft.PowerShell.PSResourceGet is missing from this PowerShell 7 install. Reinstall or repair PowerShell 7.4+.' -ForegroundColor Red
            exit 1
        }

        Write-Host 'Installing PSResourceGet for Windows PowerShell (one time)...' -ForegroundColor Yellow
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
                Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        }
        try {
            Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -Repository PSGallery -ErrorAction Stop
        }
        catch {
            Write-Host ('Could not install PSResourceGet: {0}' -f $_.Exception.Message) -ForegroundColor Red
            exit 1
        }
    }
    Import-Module -Name Microsoft.PowerShell.PSResourceGet -ErrorAction Stop
}

# --- Detect host -------------------------------------------------------------------

$hostProfile = Get-HostProfile
$psv = $PSVersionTable.PSVersion

if (-not $hostProfile) {
    Write-Host ('Unsupported PowerShell host: {0} {1}.' -f $PSVersionTable.PSEdition, $psv) -ForegroundColor Red
    Write-Host ('Supported: Windows PowerShell {0}, or PowerShell {1}.x at {2} or later.' -f $WinPSMinimum, $PwshMajor, $PwshMinimum) -ForegroundColor Red
    exit 2
}

# --- Scope policy ------------------------------------------------------------------

if ($mode -eq 'Install' -and $Scope -eq 'Both') {
    Write-Host '-Scope Both is only valid with -Remove. Install into CurrentUser or AllUsers.' -ForegroundColor Red
    exit 2
}
$scopes = @($Scope)
if ($Scope -eq 'Both') { $scopes = @('CurrentUser', 'AllUsers') }

if ($mode -ne 'Report' -and -not $ShowPlan -and $scopes -contains 'AllUsers' -and -not (Test-Elevated)) {
    $how = 'Run from an elevated session (Run as Administrator).'
    if ($hostProfile -eq 'PwshLinux') { $how = 'Run as root (sudo pwsh ...).' }
    Write-Host ('-Scope {0} changes machine-wide modules. {1}' -f $Scope, $how) -ForegroundColor Red
    exit 2
}

if ($hostProfile -eq 'WinPS') {
    # Windows PowerShell on older .NET may not offer TLS 1.2 by default. Add it
    # rather than replacing the existing setting.
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# -Report and -Remove cover the whole catalog on every host: modules this host
# installs, plus cleanup-only modules that should not be here.
$managed = $catalog
$hostSections = $sectionOrder
$installable = @($catalog | Where-Object { $_.Profiles -contains $hostProfile })
$cleanupOnly = @($catalog | Where-Object { $_.Profiles -notcontains $hostProfile })

# ===================================================================================
# REPORT
# ===================================================================================

if ($mode -eq 'Report') {
    Initialize-PSResourceGet

    Write-Host ('Installed module report - {0} (PowerShell {1})' -f $hostProfile, $psv) -ForegroundColor Cyan
    Write-Host 'Modules this host installs are always listed; cleanup-only modules are listed when a copy is found.' -ForegroundColor Gray

    $presentInstallable = 0
    $driftCount = 0
    $allOther = @()
    $cleanupFound = @()      # sections with cleanup-only copies the script can remove
    $cleanupInAllUsers = $false
    $mainNames = @($managed | ForEach-Object { $_.Name })

    foreach ($s in $hostSections) {
        $items = @($managed | Where-Object { $_.Section -eq $s })
        $familyPatterns = @($items | ForEach-Object { $_.Family } | Where-Object { $_ } | Sort-Object -Unique)

        # Sub-modules of meta packages, counted once per section.
        $subs = @()
        $subOther = @()
        if ($familyPatterns.Count -gt 0) {
            $subs = @(@(Get-Installed -Patterns $familyPatterns) + @(Get-Installed -Patterns $familyPatterns -Scope AllUsers) |
                Where-Object { $mainNames -notcontains $_.Name })
            $subOther = @(Get-OtherCopies -Patterns $familyPatterns | Where-Object { $mainNames -notcontains $_.Name })
        }

        $rows = @()
        $sectionHasCleanup = $false
        foreach ($item in $items) {
            $isCleanup = $item.Profiles -notcontains $hostProfile
            $cu = @(Get-Installed -Patterns @($item.Name))
            $au = @(Get-Installed -Patterns @($item.Name) -Scope AllUsers)
            $ot = @(Get-OtherCopies -Patterns @($item.Name))
            $copies = $cu.Count + $au.Count + $ot.Count

            if ($isCleanup) {
                if (($cu.Count + $au.Count) -gt 0) { $sectionHasCleanup = $true }
                if ($au.Count -gt 0) { $cleanupInAllUsers = $true }
                # Hide absent cleanup-only modules unless their family has copies.
                if ($copies -eq 0 -and ($subs.Count + $subOther.Count) -eq 0) { continue }
            }
            elseif ($copies -gt 0) {
                $presentInstallable++
            }
            $allOther += $ot

            $notes = @()
            if ($isCleanup) { $notes += 'cleanup only' }
            if ($copies -gt 1) { $notes += 'multiple copies'; $driftCount++ }
            if ($item.Optional -and -not $isCleanup) { $notes += 'optional' }

            $cuText = '-'
            if ($cu.Count -gt 0) { $cuText = ($cu | ForEach-Object { Format-ResourceVersion $_ }) -join ', ' }
            $auText = '-'
            if ($au.Count -gt 0) { $auText = ($au | ForEach-Object { Format-ResourceVersion $_ }) -join ', ' }
            $otText = '-'
            if ($ot.Count -gt 0) { $otText = ($ot | ForEach-Object { $_.Version }) -join ', ' }

            $rows += [pscustomobject]@{
                Module      = $item.Name
                CurrentUser = $cuText
                AllUsers    = $auText
                Other       = $otText
                Notes       = ($notes -join '; ')
            }
        }

        if ($rows.Count -eq 0) { continue }

        # A cleanup-only family can be present through sub-modules alone.
        $sectionCleanupItems = @($items | Where-Object { $_.Profiles -notcontains $hostProfile })
        if ($sectionCleanupItems.Count -eq $items.Count -and $subs.Count -gt 0) {
            $sectionHasCleanup = $true
            if (@(Get-Installed -Patterns $familyPatterns -Scope AllUsers).Count -gt 0) { $cleanupInAllUsers = $true }
        }
        if ($sectionHasCleanup) { $cleanupFound += $s }

        Write-Host ("`n[{0}]" -f $sectionLabel[$s]) -ForegroundColor Yellow
        Write-Table -Rows $rows -Property Module, CurrentUser, AllUsers, Other, Notes

        if ($familyPatterns.Count -gt 0) {
            $allOther += $subOther
            $subNames = @($subs | ForEach-Object { $_.Name } | Sort-Object -Unique)
            $multi = @($subs | Group-Object Name | Where-Object { $_.Count -gt 1 })
            $line = '  Sub-modules: {0} installed (CurrentUser + AllUsers)' -f $subNames.Count
            if ($subOther.Count -gt 0) { $line += (', {0} other' -f $subOther.Count) }
            if ($multi.Count -gt 0) {
                $line += (', {0} with multiple versions ({1})' -f $multi.Count, (($multi | Select-Object -First 5 | ForEach-Object { $_.Name }) -join ', '))
                if ($multi.Count -gt 5) { $line += ', ...' }
                $driftCount += $multi.Count
            }
            Write-Host $line
        }
    }

    Write-Host ("`nInstalled for this host: {0} of {1} modules present." -f $presentInstallable, $installable.Count) -ForegroundColor Cyan
    if ($driftCount -gt 0) {
        Write-Host ('{0} module(s) have more than one copy. Use -Remove -Scope Both, then reinstall, to get back to a single copy.' -f $driftCount) -ForegroundColor Yellow
    }
    if ($cleanupFound.Count -gt 0) {
        $scopeHint = ''
        if ($cleanupInAllUsers) { $scopeHint = ' -Scope Both (elevated)' }
        Write-Host ('Cleanup-only modules found in: {0}. Remove with: -Remove -Section {1}{2}' -f (($cleanupFound | ForEach-Object { $sectionLabel[$_] }) -join ', '), ($cleanupFound -join ','), $scopeHint) -ForegroundColor Yellow
    }
    else {
        Write-Host 'No cleanup-only modules found.' -ForegroundColor Green
    }
    Write-OtherWarning -Copies @($allOther | Sort-Object Path -Unique)
    exit 0
}

# ===================================================================================
# REMOVE
# ===================================================================================

if ($mode -eq 'Remove') {
    Initialize-PSResourceGet

    # Installed footprint per section on this host.
    $scopeText = $scopes -join ' + '
    $footprint = [ordered]@{}
    foreach ($s in $hostSections) {
        $items = @($managed | Where-Object { $_.Section -eq $s })
        $patterns = Get-PatternsFor -Items $items
        $found = @(foreach ($sc in $scopes) { Get-Installed -Patterns $patterns -Scope $sc })
        if ($found.Count -gt 0) {
            $footprint[$s] = [pscustomobject]@{
                Section  = $s
                Cleanup  = (@($items | Where-Object { $_.Profiles -contains $hostProfile }).Count -eq 0)
                Patterns = $patterns
                Modules  = @($found | ForEach-Object { $_.Name } | Sort-Object -Unique)
                Versions = $found.Count
            }
        }
    }

    if ($footprint.Count -eq 0) {
        Write-Host ('Nothing managed by this script is installed in {0} scope on {1}.' -f $scopeText, $hostProfile) -ForegroundColor Green
        if ($Scope -eq 'CurrentUser') {
            $au = @(Get-Installed -Patterns (Get-PatternsFor -Items $managed) -Scope AllUsers)
            if ($au.Count -gt 0) {
                Write-Host ('{0} module version(s) are installed for AllUsers. Use -Scope AllUsers or -Scope Both from an elevated session.' -f $au.Count) -ForegroundColor Yellow
            }
        }
        Write-OtherWarning -Copies (Get-OtherCopies -Patterns (Get-PatternsFor -Items $managed))
        exit 0
    }

    $available = @($footprint.Keys)
    $chosen = @()

    if ($Section) {
        # Non-interactive.
        if ($Section -contains 'All') {
            $chosen = $available
        }
        else {
            foreach ($s in $Section) {
                if ($hostSections -notcontains $s) {
                    Write-Warning ('Section {0} is not managed on {1}; skipping.' -f $s, $hostProfile)
                }
                elseif ($available -notcontains $s) {
                    Write-Host ('Section {0}: nothing installed.' -f $s) -ForegroundColor Gray
                }
                else {
                    $chosen += $s
                }
            }
        }
    }
    else {
        if ([Console]::IsInputRedirected) {
            Write-Host 'No interactive console. Use -Section All, or -Section with one or more section names.' -ForegroundColor Red
            exit 2
        }

        Write-Host ('Installed sections on {0} ({1} scope):' -f $hostProfile, $scopeText) -ForegroundColor Cyan
        for ($i = 0; $i -lt $available.Count; $i++) {
            $f = $footprint[$available[$i]]
            $tag = ''
            if ($f.Cleanup) { $tag = '  (cleanup only - not used on this host)' }
            Write-Host ('  {0}) {1,-36} {2} module(s), {3} version(s){4}' -f ($i + 1), $sectionLabel[$f.Section], $f.Modules.Count, $f.Versions, $tag)
        }

        while ($true) {
            $answer = Read-Host 'Sections to remove (e.g. 1,3), Enter = ALL, Q = quit'
            $answer = ([string]$answer).Trim()

            if ($answer -eq '' -or $answer -ieq 'all') { $chosen = $available; break }
            if ($answer -ieq 'q') { Write-Host 'Nothing removed.'; exit 0 }

            $tokens = @($answer -split '[,\s]+' | Where-Object { $_ })
            $picked = @()
            $bad = @()
            foreach ($t in $tokens) {
                $n = 0
                if ([int]::TryParse($t, [ref]$n) -and $n -ge 1 -and $n -le $available.Count) {
                    $picked += $available[$n - 1]
                }
                elseif ($available -contains $t) {
                    $picked += @($available | Where-Object { $_ -ieq $t })
                }
                else {
                    $bad += $t
                }
            }
            if ($bad.Count -gt 0 -or $picked.Count -eq 0) {
                Write-Host ('Not recognized: {0}. Use numbers 1-{1}, section names, Enter for ALL, or Q.' -f ($bad -join ', '), $available.Count) -ForegroundColor Red
                continue
            }
            $chosen = @($picked | Select-Object -Unique)
            break
        }
    }

    if ($chosen.Count -eq 0) {
        Write-Host 'Nothing to remove.'
        exit 0
    }

    $totalVersions = 0
    foreach ($s in $chosen) { $totalVersions += $footprint[$s].Versions }
    Write-Host ('Will remove {0} module version(s) ({1} scope) from: {2}' -f $totalVersions, $scopeText, (($chosen | ForEach-Object { $sectionLabel[$_] }) -join ', ')) -ForegroundColor Yellow

    # Confirm only when the selection came from the menu; -Section is the scripted path.
    if (-not $Section -and -not $WhatIfPreference) {
        $confirm = Read-Host 'Proceed? [y/N]'
        if ($confirm -notmatch '^(y|yes)$') { Write-Host 'Nothing removed.'; exit 0 }
    }

    $allPatterns = @($chosen | ForEach-Object { $footprint[$_].Patterns } | Sort-Object -Unique)
    Write-LoadedWarning -Patterns $allPatterns

    $results = foreach ($s in $chosen) {
        Write-Host ("`nRemoving {0}..." -f $sectionLabel[$s]) -ForegroundColor Cyan
        $left = @(foreach ($sc in $scopes) { Remove-ModuleSet -Patterns $footprint[$s].Patterns -Scope $sc })
        $status = 'Removed'
        if ($WhatIfPreference) { $status = 'WhatIf' }
        elseif ($left.Count -gt 0) { $status = 'Incomplete' }
        $leftNames = @($left | ForEach-Object { $_.Name } | Sort-Object -Unique)
        [pscustomobject]@{
            Section  = $sectionLabel[$s]
            Status   = $status
            Left     = $left.Count
            Notes    = ($leftNames -join ', ')
        }
    }

    Write-Host "`n===== Remove Summary =====" -ForegroundColor Cyan
    Write-Table -Rows @($results) -Property Section, Status, Left, Notes

    if ($scopes -notcontains 'AllUsers') {
        $au = @(Get-Installed -Patterns $allPatterns -Scope AllUsers)
        if ($au.Count -gt 0) {
            Write-Warning ('{0} module version(s) from these sections are installed for AllUsers and were not touched. Re-run with -Scope AllUsers or -Scope Both from an elevated session.' -f $au.Count)
        }
    }
    # Copies this script cannot remove are checked across the whole catalog, not
    # only the chosen sections: a section holding only such copies never shows in the menu.
    Write-OtherWarning -Copies (Get-OtherCopies -Patterns (Get-PatternsFor -Items $managed))

    if (@($results | Where-Object { $_.Status -eq 'Incomplete' }).Count -gt 0) {
        Write-Host 'Some modules could not be removed (loaded in a session or locked). Try again from a fresh session.' -ForegroundColor Red
        exit 1
    }
    exit 0
}

# ===================================================================================
# INSTALL (default)
# ===================================================================================

$plan = @($installable | Where-Object { -not ($CoreOnly -and $_.Optional) })

Write-Host ('Host profile: {0}  (PowerShell {1})' -f $hostProfile, $psv) -ForegroundColor Cyan
Write-Host 'Modules planned for this host:' -ForegroundColor Cyan
foreach ($m in $plan) {
    $tag = ''
    if ($m.Optional) { $tag = '  (optional)' }
    Write-Host ('  [{0}] {1}{2}' -f $m.Section, $m.Name, $tag)
}
if ($cleanupOnly.Count -gt 0) {
    Write-Host 'Cleanup-only on this host (never installed here; -Report and -Remove cover them):' -ForegroundColor Gray
    foreach ($m in $cleanupOnly) {
        $where = 'never installed (legacy)'
        if ($m.Profiles.Count -gt 0) { $where = 'installs on ' + ($m.Profiles -join ', ') }
        Write-Host ('  [{0}] {1}  -> {2}' -f $m.Section, $m.Name, $where) -ForegroundColor Gray
    }
}

if ($ShowPlan) { exit 0 }

Initialize-PSResourceGet

# Make sure the repository exists. Trust is passed per call (-TrustRepository)
# instead of changing the repository's persistent trust setting.
if (-not (Get-PSResourceRepository -Name $Repository -ErrorAction SilentlyContinue)) {
    if ($Repository -eq 'PSGallery') {
        Write-Host 'Registering PSGallery repository...' -ForegroundColor Yellow
        Register-PSResourceRepository -PSGallery -ErrorAction SilentlyContinue -WhatIf:$false
    }
    if (-not (Get-PSResourceRepository -Name $Repository -ErrorAction SilentlyContinue)) {
        Write-Host ('Repository {0} is not registered. Nothing was changed.' -f $Repository) -ForegroundColor Red
        exit 1
    }
}

# --- Resolve everything before touching anything ---------------------------------

$results = [System.Collections.Generic.List[pscustomobject]]::new()
$resolved = @{}
$lookupFailed = $false

Write-Host ("`nResolving modules on {0}..." -f $Repository) -ForegroundColor Cyan
foreach ($m in $plan) {
    $before = @(Get-Installed -Patterns @($m.Name) -Scope $Scope)
    $beforeText = '-'
    if ($before.Count -gt 0) { $beforeText = ($before | ForEach-Object { Format-ResourceVersion $_ }) -join ', ' }

    try {
        $latest = Find-PSResource -Name $m.Name -Repository $Repository -ErrorAction Stop |
            Sort-Object Version -Descending | Select-Object -First 1
        if (-not $latest) { throw ('{0} was not found in {1}.' -f $m.Name, $Repository) }

        $resolved[$m.Name] = [pscustomobject]@{
            Before = $beforeText
            Latest = Format-ResourceVersion $latest
        }
        Write-Host ('  {0}: installed {1}, available {2}' -f $m.Name, $beforeText, $resolved[$m.Name].Latest)
    }
    catch {
        $lookupFailed = $true
        Write-Host ('  {0}: lookup failed - {1}' -f $m.Name, $_.Exception.Message) -ForegroundColor Red
        $results.Add([pscustomobject]@{
            Module = $m.Name; Before = $beforeText; After = '-'; Status = 'LookupFailed'; Notes = $_.Exception.Message
        })
    }
}

if ($lookupFailed) {
    Write-Host "`nOne or more modules could not be resolved. Nothing was uninstalled or installed." -ForegroundColor Red
    Write-Table -Rows $results.ToArray() -Property Module, Status, Notes
    exit 1
}

# --- Sweep ------------------------------------------------------------------------

$leftovers = @()
if (-not $SkipUninstall) {
    $patterns = Get-PatternsFor -Items $plan
    Write-LoadedWarning -Patterns $patterns

    Write-Host ("`nRemoving installed versions ({0} scope)..." -f $Scope) -ForegroundColor Cyan
    $leftovers = @(Remove-ModuleSet -Patterns $patterns -Scope $Scope)
    if ($leftovers.Count -gt 0 -and -not $WhatIfPreference) {
        Write-Warning ('Could not remove {0} module version(s): {1}. They may be loaded or locked.' -f $leftovers.Count, (($leftovers | ForEach-Object { $_.Name } | Sort-Object -Unique) -join ', '))
    }
}

# --- Install ----------------------------------------------------------------------

foreach ($m in $plan) {
    $version = $resolved[$m.Name].Latest
    Write-Host ("`nInstalling {0} {1}..." -f $m.Name, $version) -ForegroundColor Yellow

    if (-not $PSCmdlet.ShouldProcess(('{0} {1}' -f $m.Name, $version), 'Install-PSResource')) {
        $results.Add([pscustomobject]@{ Module = $m.Name; Before = $resolved[$m.Name].Before; After = '-'; Status = 'WhatIf'; Notes = '' })
        continue
    }

    $status = 'Failed'
    $notes  = ''
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            # Install exactly the version resolved above, so the run is consistent
            # even if the repository publishes something new mid-run.
            Install-PSResource -Name $m.Name -Version ('[{0}]' -f $version) -Repository $Repository `
                -Scope $Scope -TrustRepository -AcceptLicense -ErrorAction Stop -WhatIf:$false -Confirm:$false
            $status = 'Success'
            if ($attempt -gt 1) { $status = 'Success (after retry)' }
            break
        }
        catch {
            $notes = $_.Exception.Message
            if ($attempt -eq 1) {
                Write-Host '  Install failed, retrying...' -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }

    $after = @(Get-Installed -Patterns @($m.Name) -Scope $Scope)
    $afterText = '-'
    if ($after.Count -gt 0) { $afterText = ($after | ForEach-Object { Format-ResourceVersion $_ }) -join ', ' }

    if ($status -like 'Success*' -and -not ($after | Where-Object { (Format-ResourceVersion $_) -eq $version })) {
        $status = 'Failed'
        $notes  = 'Install reported success but the resolved version is not present.'
    }

    $results.Add([pscustomobject]@{
        Module = $m.Name
        Before = $resolved[$m.Name].Before
        After  = $afterText
        Status = $status
        Notes  = $notes
    })
}

# --- Summary ----------------------------------------------------------------------

Write-Host ("`n===== Install Summary ({0}, {1} scope) =====" -f $hostProfile, $Scope) -ForegroundColor Cyan
Write-Table -Rows $results.ToArray() -Property Module, Before, After, Status, Notes

$failed = @($results | Where-Object { $_.Status -notlike 'Success*' -and $_.Status -ne 'WhatIf' })
$exitCode = 0

if ($failed.Count -gt 0) {
    Write-Host ('{0} module(s) did not install cleanly.' -f $failed.Count) -ForegroundColor Red
    $exitCode = 1
}
if ($leftovers.Count -gt 0 -and -not $WhatIfPreference) {
    Write-Host 'The sweep left modules behind, so this is not a single-version install.' -ForegroundColor Red
    $exitCode = 1
}
if ($exitCode -eq 0 -and -not $WhatIfPreference) {
    Write-Host 'All modules installed successfully.' -ForegroundColor Green
}

# Copies outside the scope we just installed into. CurrentUser comes first on
# PSModulePath, so a CurrentUser copy wins over an AllUsers install of the same
# module; an AllUsers copy is a stale duplicate next to a CurrentUser install.
$planPatterns = Get-PatternsFor -Items $plan
$otherScope = 'AllUsers'
if ($Scope -eq 'AllUsers') { $otherScope = 'CurrentUser' }
$other = @(Get-Installed -Patterns $planPatterns -Scope $otherScope)
if ($other.Count -gt 0) {
    $effect = 'stale duplicates of what was just installed'
    if ($Scope -eq 'AllUsers') { $effect = 'loaded INSTEAD of the AllUsers copies, because CurrentUser comes first on PSModulePath' }
    Write-Warning ('{0} module version(s) are also installed for {1}; they are {2}. Clean them with -Remove -Scope {1}.' -f $other.Count, $otherScope, $effect)
}
Write-OtherWarning -Copies (Get-OtherCopies -Patterns $planPatterns)

# Cleanup-only modules sitting on this host (not touched by install).
$strays = @()
foreach ($s in $sectionOrder) {
    $items = @($cleanupOnly | Where-Object { $_.Section -eq $s })
    if ($items.Count -eq 0) { continue }
    $pat = Get-PatternsFor -Items $items
    if ((@(Get-Installed -Patterns $pat).Count + @(Get-Installed -Patterns $pat -Scope AllUsers).Count) -gt 0) { $strays += $s }
}
if ($strays.Count -gt 0) {
    Write-Warning ('Modules that do not belong on {0} are installed: {1}. Install leaves them alone; see -Report, then -Remove -Section {2}.' -f $hostProfile, (($strays | ForEach-Object { $sectionLabel[$_] }) -join ', '), ($strays -join ','))
}

switch ($hostProfile) {
    'WinPS'       { Write-Host "`nThe modern cross-platform modules install from PowerShell 7: run this script again with pwsh." -ForegroundColor Cyan }
    'PwshWindows' { Write-Host "`nThe Windows PowerShell-only modules install from powershell.exe: run this script again there." -ForegroundColor Cyan }
}

exit $exitCode
