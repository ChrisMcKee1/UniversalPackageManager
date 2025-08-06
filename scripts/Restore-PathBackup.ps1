#Requires -Version 7.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    PATH Recovery Utility for Universal Package Manager
.DESCRIPTION
    Emergency recovery tool to restore PATH environment variables from backup files
    created by the PackageManagerInstaller.
.PARAMETER BackupFile
    Path to the backup JSON file to restore from
.PARAMETER BackupId
    Backup ID to search for in the backups directory
.PARAMETER ListBackups
    List all available backup files
.EXAMPLE
    .\Restore-PathBackup.ps1 -ListBackups
    List all available backup files
.EXAMPLE
    .\Restore-PathBackup.ps1 -BackupId "master-20240806-143022"
    Restore from specific backup ID
.NOTES
    This is an emergency recovery tool. Use with caution.
    Always verify backup integrity before restoration.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BackupFile = "",
    
    [Parameter(Mandatory = $false)]
    [string]$BackupId = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$ListBackups
)

# Script variables
$script:BaseDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:BackupDir = Join-Path $script:BaseDir "backups"

function Write-RecoveryLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    $color = switch ($Level) {
        "Info"    { $PSStyle.Foreground.White }
        "Success" { $PSStyle.Foreground.Green }
        "Warning" { $PSStyle.Foreground.Yellow }
        "Error"   { $PSStyle.Foreground.Red }
    }
    
    $prefix = switch ($Level) {
        "Info"    { "INFO:" }
        "Success" { "SUCCESS:" }
        "Warning" { "WARNING:" }
        "Error"   { "ERROR:" }
    }
    
    Write-Host "$color[$timestamp] [RECOVERY] $prefix $Message$($PSStyle.Reset)"
}

function Get-AvailableBackups {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path $script:BackupDir)) {
        Write-RecoveryLog "No backup directory found: $script:BackupDir" -Level "Error"
        return @()
    }
    
    $backupFiles = Get-ChildItem -Path $script:BackupDir -Filter "PATH-backup-*.json" | Sort-Object CreationTime -Descending
    
    $backups = @()
    foreach ($file in $backupFiles) {
        try {
            $backup = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $backups += @{
                File = $file.FullName
                BackupId = $backup.BackupId
                Timestamp = $backup.Timestamp
                Size = $file.Length
                UserPathLength = if ($backup.UserPath) { $backup.UserPath.Length } else { 0 }
                MachinePathLength = if ($backup.MachinePath) { $backup.MachinePath.Length } else { 0 }
            }
        }
        catch {
            Write-RecoveryLog "Failed to read backup file: $($file.Name)" -Level "Warning"
        }
    }
    
    return $backups
}

function Test-BackupIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Backup
    )
    
    # Check required fields
    $requiredFields = @('BackupId', 'UserPath', 'MachinePath', 'SessionPath', 'Timestamp')
    foreach ($field in $requiredFields) {
        if (-not $Backup.ContainsKey($field)) {
            Write-RecoveryLog "Backup missing required field: $field" -Level "Error"
            return $false
        }
    }
    
    # Check for critical system paths in machine PATH (case-insensitive)
    $criticalPaths = @(
        "$env:SystemRoot\system32",
        "$env:SystemRoot",
        "$env:SystemRoot\System32\Wbem"
    )
    
    $machinePath = $Backup.MachinePath
    foreach ($criticalPath in $criticalPaths) {
        $found = $false
        $machinePathElements = $machinePath -split ';' | Where-Object { $_.Trim() -ne '' }
        foreach ($element in $machinePathElements) {
            if ($element.Trim() -ieq $criticalPath) {
                $found = $true
                break
            }
        }
        if (-not $found) {
            Write-RecoveryLog "Critical system path missing from backup: $criticalPath" -Level "Error"
            return $false
        }
    }
    
    # Check PATH length
    if ($Backup.UserPath -and $Backup.UserPath.Length -gt 8191) {
        Write-RecoveryLog "User PATH in backup exceeds Windows limit" -Level "Warning"
    }
    
    if ($Backup.MachinePath -and $Backup.MachinePath.Length -gt 8191) {
        Write-RecoveryLog "Machine PATH in backup exceeds Windows limit" -Level "Warning"
    }
    
    return $true
}

function Invoke-PathRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Backup
    )
    
    Write-RecoveryLog "Starting PATH restoration from backup: $($Backup.BackupId)" -Level "Warning"
    
    # Validate backup integrity
    if (-not (Test-BackupIntegrity -Backup $Backup)) {
        Write-RecoveryLog "Backup failed integrity check. Restoration aborted." -Level "Error"
        return $false
    }
    
    try {
        # Create current backup before restoration
        $emergencyBackupId = "emergency-restore-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $currentUserPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
        $currentMachinePath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
        $currentSessionPath = $env:PATH
        
        $emergencyBackup = @{
            UserPath = $currentUserPath
            MachinePath = $currentMachinePath
            SessionPath = $currentSessionPath
            Timestamp = Get-Date
            BackupId = $emergencyBackupId
        }
        
        $emergencyBackupFile = Join-Path $script:BackupDir "PATH-backup-$emergencyBackupId.json"
        $emergencyBackup | ConvertTo-Json -Depth 3 | Set-Content -Path $emergencyBackupFile -Encoding UTF8
        Write-RecoveryLog "Emergency backup created: $emergencyBackupFile" -Level "Success"
        
        # Restore user PATH
        Write-RecoveryLog "Restoring User PATH..." -Level "Info"
        [Environment]::SetEnvironmentVariable("PATH", $Backup.UserPath, [EnvironmentVariableTarget]::User)
        
        # Update current session
        $env:PATH = $Backup.SessionPath
        
        # Verify restoration
        $verifyUserPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
        if ($verifyUserPath -eq $Backup.UserPath) {
            Write-RecoveryLog "User PATH successfully restored" -Level "Success"
        } else {
            Write-RecoveryLog "User PATH restoration verification failed" -Level "Error"
            return $false
        }
        
        Write-RecoveryLog "PATH restoration completed successfully" -Level "Success"
        Write-RecoveryLog "Emergency backup saved as: $emergencyBackupId" -Level "Info"
        
        return $true
    }
    catch {
        Write-RecoveryLog "PATH restoration failed: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Main execution
try {
    Write-Host "$($PSStyle.Foreground.Cyan)Universal Package Manager - PATH Recovery Utility$($PSStyle.Reset)"
    Write-Host "$($PSStyle.Foreground.Cyan)=====================================================$($PSStyle.Reset)"
    Write-Host ""
    
    # Verify admin privileges
    $currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        Write-RecoveryLog "This utility must be run as Administrator" -Level "Error"
        exit 1
    }
    
    Write-RecoveryLog "Administrator privileges verified" -Level "Success"
    Write-RecoveryLog "Backup directory: $script:BackupDir" -Level "Info"
    
    if ($ListBackups) {
        Write-RecoveryLog "Available PATH backups:" -Level "Info"
        $backups = Get-AvailableBackups
        
        if ($backups.Count -eq 0) {
            Write-RecoveryLog "No backup files found" -Level "Warning"
            exit 0
        }
        
        Write-Host ""
        foreach ($backup in $backups) {
            Write-Host "Backup ID: $($backup.BackupId)" -ForegroundColor Cyan
            Write-Host "  Timestamp: $($backup.Timestamp)"
            Write-Host "  File: $($backup.File)"
            Write-Host "  User PATH Length: $($backup.UserPathLength) chars"
            Write-Host "  Machine PATH Length: $($backup.MachinePathLength) chars"
            Write-Host ""
        }
        
        exit 0
    }
    
    # Load backup
    $backupToRestore = $null
    
    if ($BackupFile) {
        if (-not (Test-Path $BackupFile)) {
            Write-RecoveryLog "Backup file not found: $BackupFile" -Level "Error"
            exit 1
        }
        
        try {
            $backupToRestore = Get-Content $BackupFile -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-RecoveryLog "Failed to read backup file: $($_.Exception.Message)" -Level "Error"
            exit 1
        }
    }
    elseif ($BackupId) {
        $backups = Get-AvailableBackups
        $matchingBackup = $backups | Where-Object { $_.BackupId -eq $BackupId } | Select-Object -First 1
        
        if (-not $matchingBackup) {
            Write-RecoveryLog "Backup ID not found: $BackupId" -Level "Error"
            Write-RecoveryLog "Use -ListBackups to see available backups" -Level "Info"
            exit 1
        }
        
        try {
            $backupToRestore = Get-Content $matchingBackup.File -Raw | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-RecoveryLog "Failed to read backup file: $($_.Exception.Message)" -Level "Error"
            exit 1
        }
    }
    else {
        Write-RecoveryLog "No backup specified. Use -BackupFile, -BackupId, or -ListBackups" -Level "Error"
        exit 1
    }
    
    # Confirm restoration
    Write-RecoveryLog "About to restore PATH from backup: $($backupToRestore.BackupId)" -Level "Warning"
    Write-RecoveryLog "Backup timestamp: $($backupToRestore.Timestamp)" -Level "Info"
    Write-Host ""
    
    $confirmation = Read-Host "This will overwrite your current PATH. Continue? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-RecoveryLog "Restoration cancelled by user" -Level "Info"
        exit 0
    }
    
    # Perform restoration
    $success = Invoke-PathRestore -Backup $backupToRestore
    
    if ($success) {
        Write-RecoveryLog "PATH restoration completed successfully" -Level "Success"
        Write-RecoveryLog "You may need to restart PowerShell sessions for changes to take effect" -Level "Info"
    } else {
        Write-RecoveryLog "PATH restoration failed" -Level "Error"
        exit 1
    }
}
catch {
    Write-RecoveryLog "Recovery utility failed: $($_.Exception.Message)" -Level "Error"
    exit 1
}