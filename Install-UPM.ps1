#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager v3.0 Installation Script
.DESCRIPTION
    Installs and configures the Universal Package Manager v3.0 as a Windows scheduled task
    with automatic package updates using PowerShell 7+ exclusive features.
    Always performs a clean reinstall by removing existing tasks first.
.PARAMETER UpdateTime
    Time of day to run updates (HH:MM format)
.PARAMETER Frequency
    Update frequency (Daily or Weekly)
.NOTES
    Version: 3.0
    Requires: Administrator privileges and PowerShell 7.0+
    This script always performs a clean reinstall
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$UpdateTime = "02:00",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Daily", "Weekly")]  
    [string]$Frequency = "Daily"
)

# Modern PowerShell 7+ error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$BaseDir = "C:\ProgramData\UniversalPackageManager"
$ScriptPath = Join-Path $BaseDir "UniversalPackageManager.ps1"

Write-Host "Universal Package Manager v3.0 Installation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Write-InstallLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $color = switch ($Level) {
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }
    
    $prefix = switch ($Level) {
        "Info"    { "INFO:" }
        "Success" { "SUCCESS:" }
        "Warning" { "WARNING:" }
        "Error"   { "ERROR:" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Verify we're running as administrator
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        throw "This script must be run as Administrator. Please right-click and 'Run as Administrator'"
    }
    
    Write-InstallLog "Administrator privileges verified" -Level "Success"
}
catch {
    Write-InstallLog $_.Exception.Message -Level "Error"
    exit 1
}

# PowerShell 7+ is already enforced by #Requires directive
Write-InstallLog "PowerShell version: $($PSVersionTable.PSVersion)" -Level "Success"

# Validate main script exists
try {
    if (-not (Test-Path $ScriptPath -PathType Leaf)) {
        throw "Universal Package Manager script not found at: $ScriptPath. Please ensure all files are properly extracted."
    }
    
    Write-InstallLog "Main script validated: $ScriptPath" -Level "Success"
}
catch {
    Write-InstallLog $_.Exception.Message -Level "Error"
    exit 1
}

try {
    Write-InstallLog "Setting up permissions for SYSTEM and Administrators" -Level "Info"
    
    # Set comprehensive permissions on the directory for SYSTEM and Administrators
    $acl = Get-Acl $BaseDir
    
    # SYSTEM full control
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "SYSTEM", 
        "FullControl", 
        "ContainerInherit,ObjectInherit", 
        "None", 
        "Allow"
    )
    $acl.SetAccessRule($systemRule)
    
    # Administrators full control
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Administrators", 
        "FullControl", 
        "ContainerInherit,ObjectInherit", 
        "None", 
        "Allow"
    )
    $acl.SetAccessRule($adminRule)
    
    Set-Acl -Path $BaseDir -AclObject $acl
    
    Write-InstallLog "Locating PowerShell 7+ installation" -Level "Info"
    
    $pwsh7Paths = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles}\PowerShell\7\pwsh.exe"
    )
    
    # Also check PATH
    $pathPwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if ($pathPwsh) {
        $pwsh7Paths += $pathPwsh
    }
    
    # Find first valid PowerShell 7+ installation
    $pwshPath = $null
    $detectedVersion = $null
    
    foreach ($candidatePath in $pwsh7Paths) {
        if ($candidatePath -and (Test-Path $candidatePath -PathType Leaf)) {
            try {
                $versionOutput = & $candidatePath -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
                $version = [Version]$versionOutput
                if ($version.Major -ge 7) {
                    $pwshPath = $candidatePath
                    $detectedVersion = $version
                    break
                }
            }
            catch {
                # Continue checking other paths
                continue
            }
        }
    }
    
    if (-not $pwshPath -or -not $detectedVersion) {
        Write-Error "ERROR: PowerShell 7+ executable not found or not functional!"
        Write-Host ""
        Write-Host "Searched locations:" -ForegroundColor Yellow
        $pwsh7Paths | ForEach-Object { Write-Host "  * $_" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "Please install PowerShell 7+ first:" -ForegroundColor Red
        Write-Host "  * Microsoft Store: Search 'PowerShell'"
        Write-Host "  * Direct: https://github.com/PowerShell/PowerShell/releases"
        Write-Host "  * Winget: winget install Microsoft.PowerShell"
        exit 1
    }
    
    Write-InstallLog "Found PowerShell $detectedVersion at: $pwshPath" -Level "Success"
    
    $taskName = "Universal Package Manager v3.0"
    $arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`" -Operation Update -Silent -LogLevel Info"
    
    Write-InstallLog "Configuring task to run as SYSTEM with HIGHEST privileges" -Level "Info"
    Write-InstallLog "Using PowerShell $detectedVersion for execution" -Level "Info"
    
    # Always remove existing task for clean reinstall
    Write-InstallLog "Performing clean reinstall - removing existing scheduled task" -Level "Info"
    
    try {
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-InstallLog "Removed existing task: $taskName" -Level "Success"
            Write-InstallLog "Previous task ran as: $($existingTask.Principal.UserId) ($($existingTask.Principal.RunLevel))" -Level "Info"
        } else {
            Write-InstallLog "No existing task found - proceeding with fresh installation" -Level "Info"
        }
    }
    catch {
        Write-InstallLog "Failed to remove existing task: $($_.Exception.Message)" -Level "Warning"
        # Continue with installation anyway
    }
    
    # Create task action
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $arguments
    
    # Create trigger based on frequency
    $trigger = switch ($Frequency) {
        "Daily"  { New-ScheduledTaskTrigger -Daily -At $UpdateTime }
        "Weekly" { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $UpdateTime }
    }
    
    # Enhanced settings for reliability and admin execution
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 5) `
        -Priority 4 `
        -MultipleInstances IgnoreNew
    
    # CRITICAL: Configure to run as SYSTEM with HIGHEST privileges
    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest
    
    Write-InstallLog "Creating new scheduled task with SYSTEM privileges" -Level "Info"
    
    # Register the task
    $task = Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force
    
    Write-InstallLog "Scheduled task registered successfully" -Level "Success"
    
    Write-InstallLog "Testing installation" -Level "Info"
    
    # Test the script manually first
    try {
        if ($pwshPath -like "*pwsh.exe") {
            # PowerShell 7+
            $testResult = & $pwshPath -ExecutionPolicy Bypass -File $ScriptPath -Operation Update -DryRun -Silent
        } else {
            # Windows PowerShell
            $testResult = & PowerShell.exe -ExecutionPolicy Bypass -File $ScriptPath -Operation Update -DryRun -Silent
        }
        $testSuccess = $LASTEXITCODE -eq 0
    }
    catch {
        $testSuccess = $false
        Write-Warning "Test run encountered an issue: $($_.Exception.Message)"
    }
    
    if ($testSuccess) {
        Write-InstallLog "Installation completed successfully!" -Level "Success"
        Write-Host ""
        
        Write-Host "Configuration Summary:" -ForegroundColor Cyan
        Write-Host "   Installation: $BaseDir"
        Write-Host "   Schedule: $Frequency at $UpdateTime"
        Write-Host "   Logs: $BaseDir\logs\"
        Write-Host "   Config: $BaseDir\config\settings.json"
        Write-Host "   PowerShell: $pwshPath (v$detectedVersion)"
        Write-Host "   Run Level: SYSTEM with Highest Privileges"
        Write-Host "   Version: 3.0 (PowerShell 7+ Exclusive)"
        Write-Host ""
        
        Write-Host "Usage Examples:" -ForegroundColor Cyan
        Write-Host "   # Run manual update:"
        Write-Host "   pwsh -File `"$ScriptPath`""
        Write-Host ""
        Write-Host "   # Configure settings:"
        Write-Host "   pwsh -File `"$ScriptPath`" -Operation Configure"
        Write-Host ""
        Write-Host "   # Check status:"
        Write-Host "   pwsh -File `"$ScriptPath`" -Operation Status"
        Write-Host ""
        Write-Host "   # View scheduled task:"
        Write-Host "   taskschd.msc"
        Write-Host ""
        
        Write-InstallLog "Your packages will now be updated automatically $Frequency at $UpdateTime" -Level "Success"
        Write-InstallLog "The task runs with SYSTEM privileges and can install/update any software" -Level "Success"
        
        # Verify task configuration
        try {
            $createdTask = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
            if ($createdTask.Principal.UserId -eq "SYSTEM" -and $createdTask.Principal.RunLevel -eq "Highest") {
                Write-InstallLog "Scheduled task verified: Running as SYSTEM with Highest privileges" -Level "Success"
            } else {
                Write-InstallLog "Task created but privileges may not be correctly configured" -Level "Warning"
            }
        }
        catch {
            Write-InstallLog "Could not verify task configuration: $($_.Exception.Message)" -Level "Warning"
        }
    }
    else {
        Write-InstallLog "Installation completed but test failed" -Level "Warning"
        Write-InstallLog "The scheduled task has been created and should work when run automatically" -Level "Info"
        Write-InstallLog "Check the logs after the first scheduled run: $BaseDir\logs\" -Level "Info"
    }
}
catch {
    Write-InstallLog "Installation failed: $($_.Exception.Message)" -Level "Error"
    
    if ($_.Exception.InnerException) {
        Write-InstallLog "Inner exception: $($_.Exception.InnerException.Message)" -Level "Error"
    }
    
    Write-Host "\nFor troubleshooting help:" -ForegroundColor Yellow
    Write-Host "1. Ensure you're running as Administrator"
    Write-Host "2. Verify PowerShell 7+ is properly installed"
    Write-Host "3. Check Windows Event Viewer for additional details"
    Write-Host "4. Try running: Get-ExecutionPolicy -List"
    
    exit 1
}

Write-Host ""
Write-InstallLog "Universal Package Manager v3.0 installation process complete!" -Level "Success"
Write-InstallLog "The Universal Package Manager will run with full SYSTEM privileges" -Level "Success"
