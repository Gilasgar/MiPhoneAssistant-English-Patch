<#
.SYNOPSIS
    Mi Phone Assistant English Patch - interactive patcher and restorer.

.DESCRIPTION
    Menu-driven tool that installs the English XML resource overlay for
    Mi Phone Assistant 4.2.1028.10 or restores a previous backup.
    Backups are created in a "Backups" folder next to this script.

.NOTES
    Test project for study purposes only. Not affiliated with Xiaomi.
    Never use on a phone you depend on.
#>

[CmdletBinding()]
param(
    [string]$InstallDir
)

$ErrorActionPreference = "Stop"

$ExpectedVersion = "4.2.1028.10"
$OverlayRoot = Join-Path $PSScriptRoot "resources\mi_phone_assistant.res"
$BackupRoot = Join-Path $PSScriptRoot "Backups"
$DefaultInstallDir = "C:\Program Files (x86)\MiPhoneAssistant"

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor DarkCyan
    Write-Host "       Mi Phone Assistant - English Patch  (v$ExpectedVersion)" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Disclaimer {
    Write-Host "  DISCLAIMER" -ForegroundColor Yellow
    Write-Host "  ----------" -ForegroundColor Yellow
    Write-Host "  * This is a TEST project made for study purposes only."
    Write-Host "  * We do NOT guarantee how the Mi Phone Assistant app will behave"
    Write-Host "    after patching, or how it will interact with your phone."
    Write-Host "  * The patch was tested and worked on a single local machine only."
    Write-Host "  * NEVER use this with your daily/working phone - a misbehaving"
    Write-Host "    flash or backup tool may cause damage to the phone." -ForegroundColor Red
    Write-Host "  * Images were intentionally NOT translated, for better"
    Write-Host "    compatibility and to avoid UI misalignment."
    Write-Host "  * Not affiliated with or endorsed by Xiaomi."
    Write-Host ""
}

function Read-YesNo {
    param([Parameter(Mandatory = $true)][string]$Prompt)

    while ($true) {
        $answer = Read-Host "  $Prompt [y/n]"
        switch -Regex ($answer.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
            default { Write-Host "  Please answer y or n." -ForegroundColor Yellow }
        }
    }
}

function Wait-KeyPress {
    Write-Host ""
    Write-Host "  Press Enter to return to the menu..." -ForegroundColor DarkGray
    [void](Read-Host)
}

# ---------------------------------------------------------------------------
# Shared checks
# ---------------------------------------------------------------------------

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw "Administrator privileges are required to modify files under Program Files. Re-run PowerShell as Administrator."
    }
}

function Assert-NotRunning {
    $running = Get-Process -Name "MiPhoneAssistant" -ErrorAction SilentlyContinue
    if ($running) {
        $ids = ($running | Select-Object -ExpandProperty Id) -join ", "
        throw "MiPhoneAssistant.exe is currently running (PID $ids). Close it first."
    }
}

function Resolve-InstallDir {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        $inputPath = Read-Host "  Mi Phone Assistant install folder [`"$DefaultInstallDir`"]"
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            $Candidate = $DefaultInstallDir
        }
        else {
            $Candidate = $inputPath
        }
    }

    if (-not (Test-Path -LiteralPath $Candidate -PathType Container)) {
        throw "Install folder does not exist: $Candidate"
    }

    return (Get-Item -LiteralPath $Candidate).FullName
}

function Test-TargetInstall {
    param([Parameter(Mandatory = $true)][string]$Path)

    $exe = Join-Path $Path "MiPhoneAssistant.exe"
    $res = Join-Path $Path "mi_phone_assistant.res"
    $config = Join-Path $Path "mi_phone_assistant.config\app_info"

    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "MiPhoneAssistant.exe was not found in: $Path"
    }

    if (-not (Test-Path -LiteralPath $res -PathType Container)) {
        throw "mi_phone_assistant.res was not found in: $Path"
    }

    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
        throw "mi_phone_assistant.config\app_info was not found in: $Path"
    }

    $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
    if ($info.FileVersion -ne $ExpectedVersion -and $info.ProductVersion -ne $ExpectedVersion) {
        throw "Unsupported Mi Phone Assistant version. Expected $ExpectedVersion, found FileVersion=$($info.FileVersion), ProductVersion=$($info.ProductVersion)."
    }

    return [pscustomobject]@{
        InstallDir = $Path
        ExePath = $exe
        ResourceDir = $res
        Version = if ($info.ProductVersion) { $info.ProductVersion } else { $info.FileVersion }
    }
}

function Test-Overlay {
    if (-not (Test-Path -LiteralPath $OverlayRoot -PathType Container)) {
        throw "Translated resource overlay is missing: $OverlayRoot"
    }

    $xmlCount = (Get-ChildItem -LiteralPath $OverlayRoot -Recurse -Filter *.xml -File | Measure-Object).Count
    if ($xmlCount -lt 50) {
        throw "Translated resource overlay looks incomplete. Found only $xmlCount XML files."
    }
}

# ---------------------------------------------------------------------------
# Patch
# ---------------------------------------------------------------------------

function New-Backup {
    param(
        [Parameter(Mandatory = $true)][string]$InstallResourceDir
    )

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = Join-Path $BackupRoot "MiPhoneAssistant_$ExpectedVersion`_$stamp"
    $backupResDir = Join-Path $backupDir "mi_phone_assistant.res"
    New-Item -ItemType Directory -Path $backupResDir -Force | Out-Null

    $manifestPath = Join-Path $backupDir "manifest.txt"
    @(
        "Mi Phone Assistant English Patch backup"
        "Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
        "Version: $ExpectedVersion"
        "Source resource directory: $InstallResourceDir"
        ""
        "Backed up files:"
    ) | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    Get-ChildItem -LiteralPath $OverlayRoot -Recurse -Filter *.xml -File | ForEach-Object {
        $relative = $_.FullName.Substring($OverlayRoot.Length).TrimStart("\")
        $source = Join-Path $InstallResourceDir $relative
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            $destination = Join-Path $backupResDir $relative
            $destinationDir = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $source -Destination $destination -Force
            Add-Content -LiteralPath $manifestPath -Encoding UTF8 -Value $relative
        }
    }

    return $backupDir
}

function Install-Overlay {
    param(
        [Parameter(Mandatory = $true)][string]$InstallResourceDir
    )

    $installed = 0
    Get-ChildItem -LiteralPath $OverlayRoot -Recurse -Filter *.xml -File | ForEach-Object {
        $relative = $_.FullName.Substring($OverlayRoot.Length).TrimStart("\")
        $target = Join-Path $InstallResourceDir $relative
        $targetDir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        $installed++
    }
    return $installed
}

function Invoke-Patch {
    Write-Banner
    Write-Host "  APPLY ENGLISH PATCH" -ForegroundColor Green
    Write-Host "  -------------------" -ForegroundColor Green
    Write-Host ""

    Test-Overlay
    $resolvedInstallDir = Resolve-InstallDir -Candidate $script:InstallDir
    $target = Test-TargetInstall -Path $resolvedInstallDir

    Write-Host ""
    Write-Host "  Verified target:" -ForegroundColor Green
    Write-Host "    Folder : $($target.InstallDir)"
    Write-Host "    Version: $($target.Version)"
    Write-Host ""

    if (-not (Read-YesNo "Patch this installation?")) {
        Write-Host "  Declined. No changes were made."
        return
    }

    Assert-Administrator
    Assert-NotRunning

    $backupDir = New-Backup -InstallResourceDir $target.ResourceDir
    $installedCount = Install-Overlay -InstallResourceDir $target.ResourceDir

    Write-Host ""
    Write-Host "  Patch complete." -ForegroundColor Green
    Write-Host "  Installed XML files: $installedCount"
    Write-Host "  Backup folder: $backupDir"
    Write-Host "  Restart Mi Phone Assistant to see the translated UI."
}

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------

function Get-Backups {
    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $BackupRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "mi_phone_assistant.res") -PathType Container } |
        Sort-Object Name -Descending)
}

function Invoke-Restore {
    Write-Banner
    Write-Host "  RESTORE ORIGINAL FILES FROM BACKUP" -ForegroundColor Green
    Write-Host "  ----------------------------------" -ForegroundColor Green
    Write-Host ""

    $backups = Get-Backups
    if ($backups.Count -eq 0) {
        Write-Host "  No backups found in: $BackupRoot" -ForegroundColor Yellow
        Write-Host "  Backups are created automatically when you apply the patch."
        return
    }

    Write-Host "  Available backups (newest first):"
    Write-Host ""
    for ($i = 0; $i -lt $backups.Count; $i++) {
        Write-Host ("    [{0}] {1}" -f ($i + 1), $backups[$i].Name)
    }
    Write-Host ("    [0] Cancel")
    Write-Host ""

    $choice = $null
    while ($true) {
        $raw = Read-Host "  Choose a backup to restore"
        if ($raw -match '^\d+$') {
            $number = [int]$raw
            if ($number -eq 0) { return }
            if ($number -ge 1 -and $number -le $backups.Count) {
                $choice = $backups[$number - 1]
                break
            }
        }
        Write-Host "  Enter a number between 0 and $($backups.Count)." -ForegroundColor Yellow
    }

    $resolvedInstallDir = Resolve-InstallDir -Candidate $script:InstallDir
    $backupResourceDir = Join-Path $choice.FullName "mi_phone_assistant.res"
    $targetResourceDir = Join-Path $resolvedInstallDir "mi_phone_assistant.res"

    if (-not (Test-Path -LiteralPath $targetResourceDir -PathType Container)) {
        throw "Target resource folder not found: $targetResourceDir"
    }

    Write-Host ""
    Write-Host "  Restore backup : $($choice.Name)"
    Write-Host "  Into           : $targetResourceDir"
    Write-Host ""

    if (-not (Read-YesNo "Restore this backup?")) {
        Write-Host "  Declined. No changes were made."
        return
    }

    Assert-Administrator
    Assert-NotRunning

    $restored = 0
    Get-ChildItem -LiteralPath $backupResourceDir -Recurse -Filter *.xml -File | ForEach-Object {
        $relative = $_.FullName.Substring($backupResourceDir.Length).TrimStart("\")
        $target = Join-Path $targetResourceDir $relative
        $targetDir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        $restored++
    }

    Write-Host ""
    Write-Host "  Restore complete. Restored XML files: $restored" -ForegroundColor Green
    Write-Host "  Restart Mi Phone Assistant."
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------

Write-Banner
Write-Disclaimer

if (-not (Read-YesNo "Do you accept this disclaimer and want to continue?")) {
    Write-Host "  Declined. No changes were made."
    exit 0
}

while ($true) {
    Write-Banner
    Write-Host "  What would you like to do?" -ForegroundColor White
    Write-Host ""
    Write-Host "    [1] Apply English patch (a backup is created first)" -ForegroundColor Green
    Write-Host "    [2] Restore original files from a backup" -ForegroundColor Cyan
    Write-Host "    [3] Show disclaimer again" -ForegroundColor Yellow
    Write-Host "    [4] Exit" -ForegroundColor DarkGray
    Write-Host ""

    $selection = Read-Host "  Select an option [1-4]"

    switch ($selection.Trim()) {
        '1' {
            try { Invoke-Patch }
            catch { Write-Host ""; Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
            Wait-KeyPress
        }
        '2' {
            try { Invoke-Restore }
            catch { Write-Host ""; Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red }
            Wait-KeyPress
        }
        '3' {
            Write-Banner
            Write-Disclaimer
            Wait-KeyPress
        }
        '4' {
            Write-Host ""
            Write-Host "  Goodbye." -ForegroundColor DarkGray
            exit 0
        }
        default {
            Write-Host "  Please choose 1, 2, 3 or 4." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
