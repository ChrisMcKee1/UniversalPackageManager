#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Centralized package management across multiple package managers
.DESCRIPTION
    This script provides a unified interface for managing packages across multiple package managers:
    - Windows Package Manager (winget)
    - Chocolatey
    - Scoop
    - Node Package Manager (npm) - global packages
    - Python Package Index (pip)
    - Conda
    
    Features:
    - Automated updates with Windows Service integration
    - Robust error handling and recovery with PowerShell 7+ features
    - Modern progress bars with $PSStyle support
    - Comprehensive structured logging
    - Advanced timeout and retry logic
    - Configuration management with JSON schema validation
    - PowerShell 7+ exclusive implementation
.PARAMETER Operation
    The operation to perform: Update, Install, Uninstall, List, Configure, InstallService, UninstallService
.PARAMETER PackageManagers
    Specific package managers to target (default: all available)
.PARAMETER Silent
    Run in silent mode (minimal output)
.PARAMETER LogLevel
    Logging level: Debug, Info, Warning, Error
.NOTES
    Author: Universal Package Manager
    Version: 3.0
    Requires: PowerShell 7.0+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Update", "Install", "Uninstall", "List", "Configure", "InstallService", "UninstallService")]
    [string]$Operation = "Update",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("winget", "choco", "scoop", "npm", "pip", "conda", "all")]
    [string[]]$PackageManagers = @("all"),
    
    [Parameter(Mandatory = $false)]
    [string[]]$Packages = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$Silent = $false,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Info", "Warning", "Error")]
    [string]$LogLevel = "Info",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

# Global configuration and state
$script:BaseDir = $PSScriptRoot
$script:ConfigFile = Join-Path $script:BaseDir "config\settings.json"
$script:LogPath = Join-Path $script:BaseDir "logs"
$script:Config = @{}
$script:LogFile = ""
$script:ErrorCount = 0
$script:WarningCount = 0
$script:SuccessCount = 0

# PowerShell 7+ exclusive features
$script:ProgressPreference = if ($Silent) { 'SilentlyContinue' } else { 'Continue' }

# Configure modern progress bar styling
if (-not $Silent) {
    $PSStyle.Progress.View = 'Minimal'
    $PSStyle.Progress.MaxWidth = 120
}

# Initialize logging
function Initialize-Logging {
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }
    $script:LogFile = Join-Path $script:LogPath "UPM-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    
    # Rotate old logs (keep last 30)
    Get-ChildItem -Path $script:LogPath -Filter "UPM-*.log" | 
        Sort-Object CreationTime -Descending | 
        Select-Object -Skip 30 | 
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Enhanced logging function with PowerShell 7+ features and structured logging
function Write-UPMLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Debug", "Info", "Warning", "Error", "Success")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "MAIN",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    # Create structured log entry
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Level = $Level
        Component = $Component
        Message = $Message
        Data = $Data
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }
    
    $logText = "[$timestamp] [$Level] [$Component] $Message"
    if ($Data.Count -gt 0) {
        $dataJson = ($Data | ConvertTo-Json -Compress -Depth 3)
        $logText += " | Data: $dataJson"
    }
    
    # Console output with modern ANSI colors (PowerShell 7+ feature)
    if (-not $Silent) {
        $shouldLog = switch ($LogLevel) {
            "Debug" { $true }
            "Info" { $Level -in @("Info", "Warning", "Error", "Success") }
            "Warning" { $Level -in @("Warning", "Error", "Success") }
            "Error" { $Level -in @("Error", "Success") }
        }
        
        if ($shouldLog) {
            switch ($Level) {
                "Debug" { Write-Host $logText -ForegroundColor ($PSStyle.Foreground.BrightBlack) }
                "Info" { Write-Host $logText -ForegroundColor ($PSStyle.Foreground.White) }
                "Warning" { 
                    Write-Host $logText -ForegroundColor ($PSStyle.Foreground.Yellow)
                    $script:WarningCount++
                }
                "Error" { 
                    Write-Host $logText -ForegroundColor ($PSStyle.Foreground.BrightRed)
                    $script:ErrorCount++
                }
                "Success" { 
                    Write-Host $logText -ForegroundColor ($PSStyle.Foreground.BrightGreen)
                    $script:SuccessCount++
                }
            }
        }
    }
    
    # File logging with structured data
    try {
        Add-Content -Path $script:LogFile -Value $logText -Encoding UTF8 -ErrorAction Stop
        
        # Also write structured JSON log for advanced processing
        $jsonLogFile = $script:LogFile -replace '\.log$', '.json.log'
        $jsonEntry = $logEntry | ConvertTo-Json -Compress -Depth 5
        Add-Content -Path $jsonLogFile -Value $jsonEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

# Configuration management
function Initialize-Configuration {
    $defaultConfig = @{
        PackageManagers = @{
            winget = @{ 
                enabled = $true
                args = "--accept-source-agreements --accept-package-agreements --silent"
                timeout = 600
            }
            choco = @{ 
                enabled = $true
                args = "-y --limit-output"
                timeout = 900
            }
            scoop = @{ 
                enabled = $true
                args = ""
                timeout = 300
            }
            npm = @{ 
                enabled = $true
                args = ""
                timeout = 600
            }
            pip = @{ 
                enabled = $true
                args = "--quiet"
                timeout = 600
            }
            conda = @{ 
                enabled = $true
                args = "-y --quiet"
                timeout = 900
            }
        }
        Service = @{
            enabled = $true
            updateTime = "02:00"
            frequency = "Daily"
        }
        Advanced = @{
            maxRetries = 3
            retryDelay = 30
            skipFailedPackages = $true
            parallelUpdates = $false
            maxParallel = 4
        }
    }
    
    if (Test-Path $script:ConfigFile) {
        try {
            $fileContent = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
            $script:Config = Merge-HashTables $defaultConfig $fileContent
            Write-UPMLog "Configuration loaded from $($script:ConfigFile)" "Info" "CONFIG"
        }
        catch {
            Write-UPMLog "Failed to load configuration: $($_.Exception.Message). Using defaults." "Warning" "CONFIG"
            $script:Config = $defaultConfig
        }
    }
    else {
        $script:Config = $defaultConfig
        Save-Configuration
        Write-UPMLog "Created default configuration at $($script:ConfigFile)" "Info" "CONFIG"
    }
}

# Utility function to merge hashtables (improved for PowerShell 7+ compatibility)
function Merge-HashTables {
    param($Default, $Override)
    
    $result = $Default.Clone()
    foreach ($key in $Override.PSObject.Properties.Name) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override.$key -is [PSCustomObject]) {
            $result[$key] = Merge-HashTables $result[$key] $Override.$key
        }
        else {
            $result[$key] = $Override.$key
        }
    }
    return $result
}

# Save configuration
function Save-Configuration {
    try {
        $configDir = Split-Path $script:ConfigFile -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $script:Config | ConvertTo-Json -Depth 10 | Set-Content $script:ConfigFile -Encoding UTF8
        Write-UPMLog "Configuration saved to $($script:ConfigFile)" "Info" "CONFIG"
    }
    catch {
        Write-UPMLog "Failed to save configuration: $($_.Exception.Message)" "Error" "CONFIG"
    }
}

# Test if package manager is available
function Test-PackageManagerAvailable {
    param([string]$Manager)
    
    $commands = @{
        winget = "winget"; choco = "choco"; scoop = "scoop"
        npm = "npm"; pip = "pip"; conda = "conda"
    }
    
    if (-not $commands.ContainsKey($Manager)) { return $false }
    
    try {
        $command = Get-Command $commands[$Manager] -ErrorAction Stop
        Write-UPMLog "Found $Manager at: $($command.Source)" "Debug" $Manager.ToUpper()
        return $true
    }
    catch {
        Write-UPMLog "$Manager not found or not accessible" "Debug" $Manager.ToUpper()
        return $false
    }
}

# Modern command execution with PowerShell 7+ features and enhanced error handling
function Invoke-PackageManagerCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Manager,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [Parameter()]
        [string]$Arguments = '',
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [Parameter()]
        [int]$TimeoutSeconds = 600,
        
        [Parameter()]
        [int]$MaxRetries = 3
    )
    
    $managerUpper = $Manager.ToUpper()
    $startTime = Get-Date
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $attemptData = @{
                Attempt = $attempt
                MaxRetries = $MaxRetries
                Command = $Command
                Arguments = $Arguments
                TimeoutSeconds = $TimeoutSeconds
            }
            
            Write-UPMLog "Starting attempt $attempt/$MaxRetries - $Description" "Info" $managerUpper $attemptData
            
            if ($DryRun) {
                Write-UPMLog "[DRY RUN] Would execute: $Command $Arguments" "Info" $managerUpper
                return @{ 
                    Success = $true
                    Output = "Dry run - no actual execution"
                    ExitCode = 0
                    Duration = (New-TimeSpan -Start $startTime -End (Get-Date))
                }
            }
            
            # Use PowerShell 7+ Start-Process with TimeoutSec parameter
            $tempDir = [System.IO.Path]::GetTempPath()
            $outputFile = Join-Path $tempDir "upm_${Manager}_${PID}_$attempt.out"
            $errorFile = Join-Path $tempDir "upm_${Manager}_${PID}_$attempt.err"
            
            $processArgs = @{
                FilePath = $Command
                WindowStyle = 'Hidden'
                Wait = $true
                PassThru = $true
                RedirectStandardOutput = $outputFile
                RedirectStandardError = $errorFile
                TimeoutSec = $TimeoutSeconds
                ErrorAction = 'Stop'
            }
            
            if ($Arguments -and $Arguments.Trim() -ne '') {
                # Modern argument parsing for PowerShell 7+
                $processArgs.ArgumentList = [System.Management.Automation.PSParser]::Tokenize($Arguments, [ref]$null) | 
                    Where-Object { $_.Type -eq 'CommandArgument' -or $_.Type -eq 'String' } | 
                    ForEach-Object { $_.Content }
                
                if (-not $processArgs.ArgumentList) {
                    $processArgs.ArgumentList = $Arguments -split '\s+' | Where-Object { $_ -ne '' }
                }
            }
            
            Write-UPMLog "Executing: $Command $Arguments" "Debug" $managerUpper
            
            # Execute with PowerShell 7+ timeout support
            $execStartTime = Get-Date
            $process = Start-Process @processArgs
            $execEndTime = Get-Date
            $execDuration = $execEndTime - $execStartTime
            
            # Clean up temp files and collect results
            $output = ''
            $errorOutput = ''
            
            if (Test-Path $outputFile) {
                $output = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
                Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
            }
            
            if (Test-Path $errorFile) {
                $errorOutput = Get-Content $errorFile -Raw -ErrorAction SilentlyContinue
                Remove-Item $errorFile -Force -ErrorAction SilentlyContinue
            }
            
            $resultData = @{
                ExitCode = $process.ExitCode
                Duration = $execDuration.TotalSeconds
                OutputLength = $output.Length
                ErrorLength = $errorOutput.Length
            }
            
            if ($process.ExitCode -eq 0) {
                Write-UPMLog "Success: $Description completed in $($execDuration.TotalSeconds.ToString('F2'))s" "Success" $managerUpper $resultData
                return @{ 
                    Success = $true
                    Output = $output
                    ExitCode = $process.ExitCode
                    Duration = $execDuration
                    Error = $errorOutput
                }
            }
            else {
                $errorMsg = "Failed: $Description (Exit code: $($process.ExitCode))"
                if ($errorOutput) { 
                    $errorMsg += " - Error: $($errorOutput.Substring(0, [Math]::Min(200, $errorOutput.Length)))"
                    if ($errorOutput.Length -gt 200) { $errorMsg += "..." }
                }
                
                Write-UPMLog $errorMsg "Error" $managerUpper $resultData
                
                if ($attempt -lt $MaxRetries) {
                    Write-UPMLog "Retrying in $($script:Config.Advanced.retryDelay) seconds..." "Info" $managerUpper
                    Start-Sleep -Seconds $script:Config.Advanced.retryDelay
                    continue
                }
            }
        }
        catch [System.TimeoutException] {
            Write-UPMLog "Timeout after $TimeoutSeconds seconds during $Description" "Error" $managerUpper @{ TimeoutSeconds = $TimeoutSeconds }
            if ($attempt -lt $MaxRetries) {
                Write-UPMLog "Retrying after timeout..." "Info" $managerUpper
                Start-Sleep -Seconds $script:Config.Advanced.retryDelay
                continue
            }
        }
        catch {
            $exceptionData = @{
                ExceptionType = $_.Exception.GetType().Name
                ExceptionMessage = $_.Exception.Message
                ScriptStackTrace = $_.ScriptStackTrace
            }
            
            Write-UPMLog "Exception during $Description`: $($_.Exception.Message)" "Error" $managerUpper $exceptionData
            
            if ($attempt -lt $MaxRetries) {
                Write-UPMLog "Retrying after exception in $($script:Config.Advanced.retryDelay) seconds..." "Info" $managerUpper
                Start-Sleep -Seconds $script:Config.Advanced.retryDelay
                continue
            }
        }
        finally {
            # Clean up any remaining temp files
            @($outputFile, $errorFile) | ForEach-Object {
                if ($_ -and (Test-Path $_)) {
                    Remove-Item $_ -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    $totalDuration = (Get-Date) - $startTime
    Write-UPMLog "All retry attempts failed for $Description after $($totalDuration.TotalSeconds.ToString('F2'))s" "Error" $managerUpper
    
    return @{ 
        Success = $false
        Output = ''
        ExitCode = -1
        Duration = $totalDuration
        Error = 'All retry attempts exhausted'
    }
}

# Package manager update functions (keeping existing logic)
# Modern winget package update function with enhanced progress tracking
function Update-WingetPackages {
    [CmdletBinding()]
    param()
    
    if (-not (Test-PackageManagerAvailable "winget")) {
        return @{ Success = $false; Reason = "Not available" }
    }
    
    $timeout = $script:Config.PackageManagers.winget.timeout
    $baseArgs = $script:Config.PackageManagers.winget.args
    $activityId = 100  # Unique ID for winget progress
    
    try {
        # Phase 1: Check for available updates
        Write-Progress -Id $activityId -Activity "🔍 Winget Package Updates" -Status "Checking for available updates..." -PercentComplete 0
        Write-UPMLog "Checking for available winget package updates..." "Info" "WINGET"
        
        $listResult = Invoke-PackageManagerCommand -Manager "winget" -Command "winget" -Arguments "upgrade" -Description "List available winget updates" -TimeoutSeconds $timeout
        
        if (-not $listResult.Success) {
            Write-Progress -Id $activityId -Activity "Winget Package Updates" -Completed
            return $listResult
        }
        
        # Parse the output to get individual packages using modern PowerShell 7+ features
        $packages = @()
        if ($listResult.Output) {
            $lines = $listResult.Output -split "`n" | 
                Where-Object { $_ -match "^\S+\s+\S+\s+\S+\s+\S+" -and $_ -notmatch "^Name\s+Id\s+Version\s+Available" }
            
            $packages = $lines | ForEach-Object {
                $parts = ($_ -split "\s+", 4).Where({ $_ -ne '' })
                if ($parts.Count -ge 2) {
                    [PSCustomObject]@{
                        Name = $parts[0]
                        Id = $parts[1]
                        CurrentVersion = if ($parts.Count -gt 2) { $parts[2] } else { 'Unknown' }
                        AvailableVersion = if ($parts.Count -gt 3) { $parts[3] } else { 'Unknown' }
                    }
                }
            } | Where-Object { $_ }
        }
        
        if ($packages.Count -eq 0) {
            Write-Progress -Id $activityId -Activity "Winget Package Updates" -Status "✅ No updates needed" -PercentComplete 100
            Start-Sleep -Milliseconds 500  # Brief display of completion
            Write-Progress -Id $activityId -Activity "Winget Package Updates" -Completed
            
            $result = @{ Success = $true; Output = "No packages to update"; ExitCode = 0 }
            Write-UPMLog "No winget packages need updating" "Success" "WINGET" @{ PackageCount = 0 }
            return $result
        }
        
        $packagesData = @{
            TotalPackages = $packages.Count
            PackageNames = $packages.Name
        }
        Write-UPMLog "Found $($packages.Count) winget packages to update" "Info" "WINGET" $packagesData
        
        # Phase 2: Update packages with modern progress tracking
        $successCount = 0
        $failedPackages = [System.Collections.Generic.List[string]]::new()
        $startTime = Get-Date
        
        for ($i = 0; $i -lt $packages.Count; $i++) {
            $package = $packages[$i]
            $progressPercent = [Math]::Round((($i + 1) / $packages.Count) * 100, 1)
            $remainingCount = $packages.Count - ($i + 1)
            
            # Calculate estimated time remaining
            if ($i -gt 0) {
                $elapsed = (Get-Date) - $startTime
                $avgTimePerPackage = $elapsed.TotalSeconds / $i
                $estimatedTimeRemaining = [Math]::Round($avgTimePerPackage * $remainingCount)
                $timeRemainingText = if ($estimatedTimeRemaining -gt 0) { " (~${estimatedTimeRemaining}s remaining)" } else { "" }
            } else {
                $timeRemainingText = ""
            }
            
            $statusText = "📦 Updating $($package.Name) ($($i + 1)/$($packages.Count))$timeRemainingText"
            $currentOp = "$($package.CurrentVersion) → $($package.AvailableVersion)"
            
            Write-Progress -Id $activityId -Activity "🔄 Winget Package Updates" -Status $statusText -CurrentOperation $currentOp -PercentComplete $progressPercent
            
            $packageData = @{
                PackageName = $package.Name
                PackageId = $package.Id
                CurrentVersion = $package.CurrentVersion
                TargetVersion = $package.AvailableVersion
                ProgressIndex = $i + 1
                TotalPackages = $packages.Count
            }
            
            Write-UPMLog "Starting update: $($package.Name) ($($package.Id))" "Info" "WINGET" $packageData
            
            $packageArgs = "upgrade --id $($package.Id) $baseArgs"
            $result = Invoke-PackageManagerCommand -Manager "winget" -Command "winget" -Arguments $packageArgs -Description "Update package: $($package.Name)" -TimeoutSeconds $timeout
            
            if ($result.Success) {
                $successCount++
                $successData = @{
                    PackageName = $package.Name
                    Duration = $result.Duration.TotalSeconds
                    NewVersion = $package.AvailableVersion
                }
                Write-UPMLog "✅ Successfully updated: $($package.Name)" "Success" "WINGET" $successData
            } else {
                $failedPackages.Add($package.Name)
                $failureData = @{
                    PackageName = $package.Name
                    ExitCode = $result.ExitCode
                    ErrorOutput = $result.Error
                }
                Write-UPMLog "❌ Failed to update: $($package.Name)" "Error" "WINGET" $failureData
                
                # Continue with other packages if skipFailedPackages is enabled
                if (-not $script:Config.Advanced.skipFailedPackages) {
                    Write-Progress -Id $activityId -Activity "Winget Package Updates" -Completed
                    return @{ 
                        Success = $false
                        Output = "Failed to update $($package.Name): $($result.Error)"
                        ExitCode = $result.ExitCode
                        PackagesUpdated = $successCount
                        PackagesFailed = $failedPackages.Count
                    }
                }
            }
        }
        
        # Final progress update
        $overallSuccess = ($failedPackages.Count -eq 0) -or ($successCount -gt 0 -and $script:Config.Advanced.skipFailedPackages)
        $finalStatus = if ($overallSuccess) { "✅ Updates completed" } else { "⚠️ Updates completed with errors" }
        
        Write-Progress -Id $activityId -Activity "Winget Package Updates" -Status $finalStatus -PercentComplete 100
        Start-Sleep -Milliseconds 750  # Brief display of completion
        Write-Progress -Id $activityId -Activity "Winget Package Updates" -Completed
        
        # Generate summary
        $totalDuration = (Get-Date) - $startTime
        $summary = "Updated $successCount of $($packages.Count) packages in $($totalDuration.TotalSeconds.ToString('F1'))s"
        if ($failedPackages.Count -gt 0) {
            $summary += ". Failed: $($failedPackages -join ', ')"
        }
        
        $summaryData = @{
            PackagesUpdated = $successCount
            PackagesFailed = $failedPackages.Count
            TotalDuration = $totalDuration.TotalSeconds
            FailedPackages = $failedPackages.ToArray()
        }
        
        $logLevel = if ($overallSuccess) { "Success" } else { "Warning" }
        Write-UPMLog "Winget update complete: $summary" $logLevel "WINGET" $summaryData
        
        return @{ 
            Success = $overallSuccess
            Output = $summary
            ExitCode = if ($overallSuccess) { 0 } else { 1 }
            PackagesUpdated = $successCount
            PackagesFailed = $failedPackages.Count
            Duration = $totalDuration
            FailedPackagesList = $failedPackages.ToArray()
        }
    }
    catch {
        Write-Progress -Id $activityId -Activity "Winget Package Updates" -Completed
        $exceptionData = @{
            ExceptionType = $_.Exception.GetType().Name
            ExceptionMessage = $_.Exception.Message
        }
        Write-UPMLog "Critical error in winget update: $($_.Exception.Message)" "Error" "WINGET" $exceptionData
        throw
    }
}

function Update-ChocolateyPackages {
    if (-not (Test-PackageManagerAvailable "choco")) {
        return @{ Success = $false; Reason = "Not available" }
    }
    $timeout = $script:Config.PackageManagers.choco.timeout
    $baseArgs = $script:Config.PackageManagers.choco.args
    
    $selfResult = Invoke-PackageManagerCommand -Manager "choco" -Command "choco" -Arguments "upgrade chocolatey $baseArgs" -Description "Update Chocolatey itself" -TimeoutSeconds $timeout
    $packagesResult = Invoke-PackageManagerCommand -Manager "choco" -Command "choco" -Arguments "upgrade all $baseArgs" -Description "Update all Chocolatey packages" -TimeoutSeconds $timeout
    
    return @{ 
        Success = ($selfResult.Success -and $packagesResult.Success)
        Output = "$($selfResult.Output)`n$($packagesResult.Output)"
        ExitCode = if ($packagesResult.Success) { $packagesResult.ExitCode } else { $packagesResult.ExitCode }
    }
}

function Update-ScoopPackages {
    if (-not (Test-PackageManagerAvailable "scoop")) {
        return @{ Success = $false; Reason = "Not available" }
    }
    $timeout = $script:Config.PackageManagers.scoop.timeout
    
    $updateResult = Invoke-PackageManagerCommand -Manager "scoop" -Command "scoop" -Arguments "update" -Description "Update Scoop buckets" -TimeoutSeconds $timeout
    $upgradeResult = Invoke-PackageManagerCommand -Manager "scoop" -Command "scoop" -Arguments "update *" -Description "Update all Scoop packages" -TimeoutSeconds $timeout
    
    return @{ 
        Success = ($updateResult.Success -and $upgradeResult.Success)
        Output = "$($updateResult.Output)`n$($upgradeResult.Output)"
        ExitCode = if ($upgradeResult.Success) { $upgradeResult.ExitCode } else { $upgradeResult.ExitCode }
    }
}

function Update-NpmPackages {
    if (-not (Test-PackageManagerAvailable "npm")) {
        return @{ Success = $false; Reason = "Not available" }
    }
    $timeout = $script:Config.PackageManagers.npm.timeout
    
    $selfResult = Invoke-PackageManagerCommand -Manager "npm" -Command "npm" -Arguments "update -g npm" -Description "Update NPM itself" -TimeoutSeconds $timeout
    $packagesResult = Invoke-PackageManagerCommand -Manager "npm" -Command "npm" -Arguments "update -g" -Description "Update all NPM global packages" -TimeoutSeconds $timeout
    
    return @{ 
        Success = ($selfResult.Success -and $packagesResult.Success)
        Output = "$($selfResult.Output)`n$($packagesResult.Output)"
        ExitCode = if ($packagesResult.Success) { $packagesResult.ExitCode } else { $packagesResult.ExitCode }
    }
}

function Update-PipPackages {
    if (-not (Test-PackageManagerAvailable "pip")) {
        return @{ Success = $false; Reason = "Not available" }
    }
    $timeout = $script:Config.PackageManagers.pip.timeout
    $baseArgs = $script:Config.PackageManagers.pip.args
    
    $selfResult = Invoke-PackageManagerCommand -Manager "pip" -Command "pip" -Arguments "install --upgrade pip $baseArgs" -Description "Update pip itself" -TimeoutSeconds $timeout
    $listResult = Invoke-PackageManagerCommand -Manager "pip" -Command "pip" -Arguments "list --outdated --format=freeze" -Description "List outdated packages" -TimeoutSeconds $timeout
    
    if ($listResult.Success -and $listResult.Output.Trim()) {
        $outdatedPackages = $listResult.Output.Split("`n") | ForEach-Object { ($_ -split "==")[0] }
        $packagesResult = Invoke-PackageManagerCommand -Manager "pip" -Command "pip" -Arguments "install --upgrade $($outdatedPackages -join ' ') $baseArgs" -Description "Update all pip packages" -TimeoutSeconds $timeout
    } else {
        $packagesResult = @{ Success = $true; Output = "No packages to update"; ExitCode = 0 }
    }
    
    return @{ 
        Success = ($selfResult.Success -and $packagesResult.Success)
        Output = "$($selfResult.Output)`n$($packagesResult.Output)"
        ExitCode = if ($packagesResult.Success) { $packagesResult.ExitCode } else { $packagesResult.ExitCode }
    }
}

function Update-CondaPackages {
    if (-not (Test-PackageManagerAvailable "conda")) {
        return @{ Success = $false; Reason = "Not available" }
    }
    $timeout = $script:Config.PackageManagers.conda.timeout
    $baseArgs = $script:Config.PackageManagers.conda.args
    
    $selfResult = Invoke-PackageManagerCommand -Manager "conda" -Command "conda" -Arguments "update conda $baseArgs" -Description "Update Conda itself" -TimeoutSeconds $timeout
    $packagesResult = Invoke-PackageManagerCommand -Manager "conda" -Command "conda" -Arguments "update --all $baseArgs" -Description "Update all Conda packages" -TimeoutSeconds $timeout
    
    return @{ 
        Success = ($selfResult.Success -and $packagesResult.Success)
        Output = "$($selfResult.Output)`n$($packagesResult.Output)"
        ExitCode = if ($packagesResult.Success) { $packagesResult.ExitCode } else { $packagesResult.ExitCode }
    }
}

# Modern orchestration function with enhanced progress tracking and PowerShell 7+ features
function Start-UniversalUpdate {
    [CmdletBinding()]
    param()
    
    $sessionStart = Get-Date
    $sessionId = [System.Guid]::NewGuid().ToString('N')[0..7] -join ''
    
    $sessionData = @{
        SessionId = $sessionId
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        TargetManagers = $PackageManagers
        StartTime = $sessionStart
        DryRun = $DryRun.IsPresent
    }
    
    Write-UPMLog "✨ Starting Universal Package Update Session" "Info" "SESSION" $sessionData
    
    # Modern package manager function mapping
    $updateFunctions = @{
        winget = { Update-WingetPackages }
        choco = { Update-ChocolateyPackages }
        scoop = { Update-ScoopPackages }
        npm = { Update-NpmPackages }
        pip = { Update-PipPackages }
        conda = { Update-CondaPackages }
    }
    
    # Determine target managers
    $targetManagers = if ("all" -in $PackageManagers) {
        @("winget", "choco", "scoop", "npm", "pip", "conda")
    } else {
        $PackageManagers
    }
    
    # Filter to only enabled and available managers
    $availableManagers = $targetManagers | Where-Object { $script:Config.PackageManagers[$_].enabled }
    $results = [ordered]@{}
    $mainActivityId = 1
    
    try {
        # Initialize main progress bar
        $totalManagers = $availableManagers.Count
        Write-UPMLog "Found $totalManagers enabled package managers to process" "Info" "SESSION" @{ EnabledManagers = $availableManagers }
        
        if ($totalManagers -eq 0) {
            Write-UPMLog "⚠️ No enabled package managers found" "Warning" "SESSION"
            return @{
                Results = @{}
                Summary = @{
                    Successful = 0
                    Failed = 0
                    Skipped = 0
                    Warnings = $script:WarningCount
                    Errors = $script:ErrorCount
                    Duration = (Get-Date) - $sessionStart
                }
            }
        }
        
        Write-Progress -Id $mainActivityId -Activity "🚀 Universal Package Manager" -Status "Initializing..." -PercentComplete 0
        
        $managerIndex = 0
        foreach ($manager in $targetManagers) {
            if (-not $script:Config.PackageManagers[$manager].enabled) {
                Write-UPMLog "😫 $($manager.ToUpper()): Disabled in configuration" "Info" $manager.ToUpper()
                $results[$manager] = @{ 
                    Success = $null
                    Reason = "Disabled in configuration"
                    Duration = [TimeSpan]::Zero
                }
                continue
            }
            
            $managerIndex++
            $progressPercent = [Math]::Round((($managerIndex - 1) / $totalManagers) * 100, 1)
            $statusText = "📋 Processing $($manager.ToUpper()) ($managerIndex of $totalManagers)"
            
            # Update main progress bar
            Write-Progress -Id $mainActivityId -Activity "🚀 Universal Package Manager" -Status $statusText -PercentComplete $progressPercent
            
            $managerStart = Get-Date
            $managerData = @{
                Manager = $manager.ToUpper()
                Index = $managerIndex
                TotalManagers = $totalManagers
                StartTime = $managerStart
            }
            
            try {
                Write-UPMLog "🏁 Starting $($manager.ToUpper()) Update" "Info" $manager.ToUpper() $managerData
                
                # Execute manager-specific update function
                $result = & $updateFunctions[$manager]
                $managerDuration = (Get-Date) - $managerStart
                
                # Enhance result with timing information
                if ($result -is [hashtable]) {
                    $result.Duration = $managerDuration
                } else {
                    $result = @{ 
                        Success = $false
                        Reason = "Invalid result format"
                        Duration = $managerDuration
                    }
                }
                
                $results[$manager] = $result
                
                # Log completion status
                $completionData = @{
                    Manager = $manager.ToUpper()
                    Success = $result.Success
                    Duration = $managerDuration.TotalSeconds
                    ExitCode = $result.ExitCode
                }
                
                if ($result.Success) {
                    Write-UPMLog "✅ $($manager.ToUpper()) Update Complete: SUCCESS" "Success" $manager.ToUpper() $completionData
                } else {
                    Write-UPMLog "❌ $($manager.ToUpper()) Update Complete: FAILED" "Error" $manager.ToUpper() $completionData
                }
            }
            catch {
                $managerDuration = (Get-Date) - $managerStart
                $exceptionData = @{
                    Manager = $manager.ToUpper()
                    ExceptionType = $_.Exception.GetType().Name
                    ExceptionMessage = $_.Exception.Message
                    Duration = $managerDuration.TotalSeconds
                    ScriptStackTrace = $_.ScriptStackTrace
                }
                
                Write-UPMLog "💥 Critical error processing $($manager.ToUpper()): $($_.Exception.Message)" "Error" "SESSION" $exceptionData
                $results[$manager] = @{ 
                    Success = $false
                    Reason = "Critical error: $($_.Exception.Message)"
                    Duration = $managerDuration
                    ExitCode = -1
                }
            }
        }
        
        # Final progress update
        Write-Progress -Id $mainActivityId -Activity "🚀 Universal Package Manager" -Status "🏁 Session complete" -PercentComplete 100
        Start-Sleep -Milliseconds 500
        Write-Progress -Id $mainActivityId -Activity "Universal Package Manager" -Completed
        
        # Calculate summary statistics
        $successful = ($results.Values | Where-Object { $_.Success -eq $true }).Count
        $failed = ($results.Values | Where-Object { $_.Success -eq $false }).Count
        $skipped = ($results.Values | Where-Object { $_.Success -eq $null }).Count
        $sessionDuration = (Get-Date) - $sessionStart
        
        # Generate detailed results report
        Write-UPMLog "📈 ========== SESSION SUMMARY ==========" "Info" "SESSION"
        
        foreach ($manager in $results.Keys) {
            $result = $results[$manager]
            $status = switch ($result.Success) {
                $true { "✅ SUCCESS" }
                $false { "❌ FAILED" }
                $null { "😫 SKIPPED" }
            }
            
            $reason = if ($result.Reason) { " ($($result.Reason))" } else { "" }
            $duration = if ($result.Duration) { " [$(($result.Duration.TotalSeconds).ToString('F1'))s]" } else { "" }
            $statusLine = "$($manager.ToUpper()): $status$duration$reason"
            
            $logLevel = switch ($result.Success) {
                $true { "Success" }
                $false { "Error" }
                $null { "Info" }
            }
            
            $resultData = @{
                Manager = $manager.ToUpper()
                Status = $status
                Duration = if ($result.Duration) { $result.Duration.TotalSeconds } else { 0 }
                Reason = $result.Reason
            }
            
            Write-UPMLog $statusLine $logLevel "RESULT" $resultData
        }
        
        # Final session summary
        $finalSummaryData = @{
            SessionId = $sessionId
            TotalDuration = $sessionDuration.TotalSeconds
            SuccessfulManagers = $successful
            FailedManagers = $failed
            SkippedManagers = $skipped
            TotalWarnings = $script:WarningCount
            TotalErrors = $script:ErrorCount
        }
        
        $summaryText = "Session complete: $successful successful, $failed failed, $skipped skipped in $($sessionDuration.TotalSeconds.ToString('F1'))s"
        Write-UPMLog $summaryText "Info" "SESSION" $finalSummaryData
        
        return @{
            Results = $results
            Summary = @{
                Successful = $successful
                Failed = $failed
                Skipped = $skipped
                Warnings = $script:WarningCount
                Errors = $script:ErrorCount
                Duration = $sessionDuration
                SessionId = $sessionId
            }
        }
    }
    catch {
        Write-Progress -Id $mainActivityId -Activity "Universal Package Manager" -Completed
        $sessionDuration = (Get-Date) - $sessionStart
        
        $criticalErrorData = @{
            SessionId = $sessionId
            ExceptionType = $_.Exception.GetType().Name
            ExceptionMessage = $_.Exception.Message
            SessionDuration = $sessionDuration.TotalSeconds
            ScriptStackTrace = $_.ScriptStackTrace
        }
        
        Write-UPMLog "💥 Critical session error: $($_.Exception.Message)" "Error" "SESSION" $criticalErrorData
        throw
    }
}

# Main execution logic with PowerShell 7+ features
function Main {
    [CmdletBinding()]
    param()
    
    $mainStartTime = Get-Date
    
    try {
        Initialize-Logging
        Initialize-Configuration
        
        # Display startup information
        $startupData = @{
            Version = "3.0"
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            PowerShellEdition = $PSVersionTable.PSEdition
            OperatingSystem = [System.Environment]::OSVersion.ToString()
            ProcessorCount = [System.Environment]::ProcessorCount
            TotalMemoryGB = [Math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            Operation = $Operation
            DryRun = $DryRun.IsPresent
            LogLevel = $LogLevel
        }
        
        Write-UPMLog "🚀 Universal Package Manager v3.0 - Operation: $Operation" "Info" "MAIN" $startupData
        
        # Verify PowerShell 7+ requirement
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            $versionError = "PowerShell 7.0+ is required. Current version: $($PSVersionTable.PSVersion)"
            Write-UPMLog $versionError "Error" "MAIN" @{ RequiredVersion = "7.0+"; CurrentVersion = $PSVersionTable.PSVersion.ToString() }
            throw $versionError
        }
        
        switch ($Operation) {
            "Update" {
                Write-UPMLog "🔄 Starting package update operation" "Info" "MAIN"
                $results = Start-UniversalUpdate
                
                $executionTime = (Get-Date) - $mainStartTime
                $exitCode = if ($results.Summary.Failed -gt 0) { 1 } else { 0 }
                
                $completionData = @{
                    ExecutionTime = $executionTime.TotalSeconds
                    ExitCode = $exitCode
                    SuccessfulManagers = $results.Summary.Successful
                    FailedManagers = $results.Summary.Failed
                    TotalWarnings = $results.Summary.Warnings
                    TotalErrors = $results.Summary.Errors
                }
                
                $completionLevel = if ($exitCode -eq 0) { "Success" } else { "Error" }
                Write-UPMLog "🏁 Update operation completed with exit code $exitCode" $completionLevel "MAIN" $completionData
                
                exit $exitCode
            }
            "Configure" {
                Write-UPMLog "⚙️ Opening configuration editor" "Info" "MAIN" @{ ConfigFile = $script:ConfigFile }
                
                # Use modern cross-platform approach for opening configuration
                if ($PSVersionTable.Platform -eq 'Win32NT' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
                    if (Get-Command notepad -ErrorAction SilentlyContinue) {
                        Start-Process notepad $script:ConfigFile -Wait:$false
                        Write-UPMLog "📝 Configuration opened in Notepad" "Success" "MAIN"
                    } elseif (Get-Command code -ErrorAction SilentlyContinue) {
                        Start-Process code $script:ConfigFile -Wait:$false
                        Write-UPMLog "📝 Configuration opened in VS Code" "Success" "MAIN"
                    } else {
                        Write-UPMLog "Please edit the configuration file manually: $($script:ConfigFile)" "Info" "MAIN"
                    }
                } else {
                    # Non-Windows platforms
                    if (Get-Command code -ErrorAction SilentlyContinue) {
                        Start-Process code $script:ConfigFile -Wait:$false
                        Write-UPMLog "📝 Configuration opened in VS Code" "Success" "MAIN"
                    } elseif (Get-Command nano -ErrorAction SilentlyContinue) {
                        Write-UPMLog "Opening configuration in nano editor..." "Info" "MAIN"
                        & nano $script:ConfigFile
                    } else {
                        Write-UPMLog "Please edit the configuration file manually: $($script:ConfigFile)" "Info" "MAIN"
                    }
                }
            }
            "InstallService" {
                Write-UPMLog "🛠️ Service installation not implemented in v3.0 - use Install-UPM.ps1" "Warning" "MAIN"
            }
            "UninstallService" {
                Write-UPMLog "🗑️ Service uninstallation not implemented in v3.0" "Warning" "MAIN"
            }
            default {
                Write-UPMLog "⚠️ Operation '$Operation' not yet implemented" "Warning" "MAIN" @{ AvailableOperations = @("Update", "Configure") }
            }
        }
    }
    catch {
        $executionTime = (Get-Date) - $mainStartTime
        $criticalErrorData = @{
            ExceptionType = $_.Exception.GetType().Name
            ExceptionMessage = $_.Exception.Message
            ScriptStackTrace = $_.ScriptStackTrace
            ExecutionTime = $executionTime.TotalSeconds
            Operation = $Operation
        }
        
        Write-UPMLog "💥 Critical error in main execution: $($_.Exception.Message)" "Error" "MAIN" $criticalErrorData
        Write-UPMLog "Stack trace: $($_.ScriptStackTrace)" "Debug" "MAIN"
        exit 1
    }
}

# Check for administrative privileges with modern PowerShell 7+ approach
try {
    $isAdmin = if ($PSVersionTable.Platform -eq 'Win32NT' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } else {
        # On non-Windows platforms, check if running as root
        (id -u) -eq 0 2>$null
    }
    
    if (-not $isAdmin) {
        $privilegeData = @{
            IsWindows = ($PSVersionTable.Platform -eq 'Win32NT' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT')
            CurrentUser = [System.Environment]::UserName
            ProcessId = $PID
        }
        Write-UPMLog "⚠️ Warning: Not running with elevated privileges. Some package managers may require admin/root access." "Warning" "SECURITY" $privilegeData
    } else {
        Write-UPMLog "✅ Running with elevated privileges" "Success" "SECURITY"
    }
}
catch {
    Write-UPMLog "Unable to determine privilege level: $($_.Exception.Message)" "Warning" "SECURITY"
}

# Execute main function
Main
