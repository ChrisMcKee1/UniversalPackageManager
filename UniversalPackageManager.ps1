#Requires -Version 7.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Universal Package Manager v3.0 - Modular PowerShell 7+ Exclusive
.DESCRIPTION
    Automatically manages and updates packages across multiple package managers
    using a modular architecture with enhanced logging and modern PowerShell features.
    
    Supported Package Managers:
    - Windows Package Manager (winget) 
    - Chocolatey
    - Scoop
    - NPM (global packages)
    - Python pip
    - Conda
.PARAMETER Operation
    Operation to perform: Update, Configure, Status
.PARAMETER SelectedPackageManagers
    Array of specific package managers to process
.PARAMETER DryRun
    Show what would be updated without making changes
.PARAMETER LogLevel
    Logging level: Debug, Info, Warning, Error
.PARAMETER Silent
    Run in silent mode with minimal output
.PARAMETER ConfigPath
    Path to configuration file
.NOTES
    Version 3.0 - PowerShell 7+ Exclusive with Modular Architecture
    Requires Administrator privileges for package installations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Update", "Configure", "Status")]
    [string]$Operation = "Update",
    
    [Parameter(Mandatory = $false)]
    [string[]]$SelectedPackageManagers = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Info", "Warning", "Error")]
    [string]$LogLevel = "Info",
    
    [Parameter(Mandatory = $false)]
    [switch]$Silent,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ""
)

# Script-level variables
$script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ModulesDir = Join-Path $script:BaseDir "modules"
$script:DefaultConfigPath = Join-Path $script:BaseDir "config\settings.json"

# Import core modules
try {
    Import-Module (Join-Path $script:ModulesDir "UPM.Logging.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.Configuration.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.ProcessExecution.psm1") -Force
    
    # Import package manager modules
    Import-Module (Join-Path $script:ModulesDir "UPM.PackageManager.Winget.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.PackageManager.Chocolatey.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.PackageManager.Scoop.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.PackageManager.Npm.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.PackageManager.Pip.psm1") -Force
    Import-Module (Join-Path $script:ModulesDir "UPM.PackageManager.Conda.psm1") -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Package manager function mapping
$script:PackageManagerFunctions = @{
    "winget" = @{
        "Test" = "Test-WingetAvailable"
        "Update" = "Update-WingetPackages" 
        "Info" = "Get-WingetInfo"
    }
    "choco" = @{
        "Test" = "Test-ChocolateyAvailable"
        "Update" = "Update-ChocolateyPackages"
        "Info" = "Get-ChocolateyInfo"
    }
    "scoop" = @{
        "Test" = "Test-ScoopAvailable"
        "Update" = "Update-ScoopPackages"
        "Info" = "Get-ScoopInfo"
    }
    "npm" = @{
        "Test" = "Test-NpmAvailable"
        "Update" = "Update-NpmPackages"
        "Info" = "Get-NpmInfo"
    }
    "pip" = @{
        "Test" = "Test-PipAvailable"
        "Update" = "Update-PipPackages"
        "Info" = "Get-PipInfo"
    }
    "conda" = @{
        "Test" = "Test-CondaAvailable"
        "Update" = "Update-CondaPackages"
        "Info" = "Get-CondaInfo"
    }
}

function Initialize-UPM {
    <#
    .SYNOPSIS
        Initialize the Universal Package Manager system
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Determine configuration path
        $configPath = if ($ConfigPath) { $ConfigPath } else { $script:DefaultConfigPath }
        
        # Initialize logging
        $logDir = Join-Path $script:BaseDir "logs"
        Initialize-UPMLogging -LogDirectory $logDir -LogLevel $LogLevel -EnableJsonLogs $true -EnableConsoleLogs (-not $Silent)
        
        Write-UPMLog -Message "Universal Package Manager v3.0 starting" -Level "Info" -Component "MAIN" -Data @{
            "PowerShellVersion" = $PSVersionTable.PSVersion.ToString()
            "Operation" = $Operation
            "DryRun" = $DryRun.IsPresent
            "LogLevel" = $LogLevel
            "ConfigPath" = $configPath
        }
        
        # Initialize configuration
        $config = Initialize-UPMConfiguration -ConfigPath $configPath -CreateIfMissing
        
        # Clean up old logs
        Remove-OldLogFiles -RetentionDays $config.Advanced.logRetentionDays
        
        return $config
    }
    catch {
        Write-Error "Failed to initialize UPM: $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-PackageManagerUpdate {
    <#
    .SYNOPSIS
        Execute update operation for a specific package manager
    .PARAMETER Name
        Package manager name
    .PARAMETER Config
        Package manager configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $timer = Start-UPMTimer -Name "PackageManager-$Name"
    
    try {
        # Get package manager functions
        $functions = $script:PackageManagerFunctions[$Name]
        if (-not $functions) {
            Write-UPMLog -Message "Package manager '$Name' is not supported" -Level "Error" -Component "MAIN"
            return $false
        }
        
        # Test availability
        Write-UPMLog -Message "Testing $Name availability" -Level "Debug" -Component "MAIN"
        $testResult = & $functions.Test
        
        if (-not $testResult.Available) {
            Write-UPMLog -Message "$Name is not available: $($testResult.Error)" -Level "Warning" -Component "MAIN"
            return $false
        }
        
        # Execute update
        Write-UPMLog -Message "Starting $Name update operation" -Level "Debug" -Component "MAIN"
        
        $updateParams = @{
            DryRun = $DryRun
            TimeoutSeconds = $Config.timeout
        }
        
        if ($Config.args) {
            $updateParams.Arguments = $Config.args
        }
        
        $updateResult = & $functions.Update @updateParams
        
        if ($updateResult.Success) {
            Write-UPMLog -Message "$Name update completed successfully" -Level "Success" -Component "MAIN" -Data $updateResult
        } else {
            Write-UPMLog -Message "$Name update failed" -Level "Error" -Component "MAIN" -Data $updateResult
        }
        
        return $updateResult.Success
    }
    catch {
        Write-UPMLog -Message "Error updating $Name`: $($_.Exception.Message)" -Level "Error" -Component "MAIN"
        return $false
    }
    finally {
        Stop-UPMTimer -Timer $timer -Component "MAIN"
    }
}

function Invoke-UpdateOperation {
    <#
    .SYNOPSIS
        Execute the update operation for all enabled package managers
    .PARAMETER Config
        UPM configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $totalTimer = Start-UPMTimer -Name "TotalUpdate"
    
    try {
        $packageManagers = Get-UPMPackageManagers -EnabledOnly
        
        # Filter to specific package managers if requested
        if ($SelectedPackageManagers.Count -gt 0) {
            $filteredManagers = @{}
            foreach ($pm in $SelectedPackageManagers) {
                if ($packageManagers.ContainsKey($pm)) {
                    $filteredManagers[$pm] = $packageManagers[$pm]
                } else {
                    Write-UPMLog -Message "Package manager '$pm' not found in configuration" -Level "Warning" -Component "MAIN"
                }
            }
            $packageManagers = $filteredManagers
        }
        
        if ($packageManagers.Count -eq 0) {
            Write-UPMLog -Message "No package managers available to update" -Level "Warning" -Component "MAIN"
            return
        }
        
        Write-UPMLog -Message "Starting update operation for $($packageManagers.Count) package managers" -Level "Info" -Component "MAIN"
        
        $results = @{}
        $successCount = 0
        
        foreach ($pmEntry in $packageManagers.GetEnumerator()) {
            $pmName = $pmEntry.Key
            $pmConfig = $pmEntry.Value
            
            Write-UPMLog -Message "Processing package manager: $pmName" -Level "Debug" -Component "MAIN"
            
            $success = Invoke-PackageManagerUpdate -Name $pmName -Config $pmConfig
            $results[$pmName] = $success
            
            if ($success) {
                $successCount++
            }
        }
        
        # Summary
        $failureCount = $packageManagers.Count - $successCount
        Write-UPMLog -Message "Update operation completed: $successCount successful, $failureCount failed" -Level "Info" -Component "MAIN" -Data @{
            "TotalManagers" = $packageManagers.Count
            "SuccessCount" = $successCount
            "FailureCount" = $failureCount
            "Results" = $results
        }
        
        if ($failureCount -eq 0) {
            Write-UPMLog -Message "All package managers updated successfully!" -Level "Success" -Component "MAIN"
        } elseif ($successCount -gt 0) {
            Write-UPMLog -Message "Some package managers failed to update" -Level "Warning" -Component "MAIN"
        } else {
            Write-UPMLog -Message "All package managers failed to update" -Level "Error" -Component "MAIN"
        }
    }
    finally {
        Stop-UPMTimer -Timer $totalTimer -Component "MAIN" | Out-Null
    }
}

function Invoke-StatusOperation {
    <#
    .SYNOPSIS
        Display status information for all package managers
    .PARAMETER Config
        UPM configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-UPMLog -Message "Universal Package Manager v3.0 - Status Report" -Level "Info" -Component "STATUS"
    
    $packageManagers = Get-UPMPackageManagers
    $availableCount = 0
    
    foreach ($pmEntry in $packageManagers.GetEnumerator()) {
        $pmName = $pmEntry.Key
        $pmConfig = $pmEntry.Value
        
        $functions = $script:PackageManagerFunctions[$pmName]
        if ($functions) {
            $info = & $functions.Info
            
            $status = if ($info.Available) {
                $availableCount++
                "Available"
            } else {
                "Not Available"
            }
            
            $enabledStatus = if ($pmConfig.enabled) { "Enabled" } else { "Disabled" }
            
            Write-UPMLog -Message "$pmName`: $status, $enabledStatus" -Level "Info" -Component "STATUS" -Data $info
        }
    }
    
    Write-UPMLog -Message "Status Summary: $availableCount/$($packageManagers.Count) package managers available" -Level "Info" -Component "STATUS"
}

function Invoke-ConfigureOperation {
    <#
    .SYNOPSIS
        Open configuration editor or display current configuration
    .PARAMETER Config
        UPM configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-UPMLog -Message "Configuration file location: $script:DefaultConfigPath" -Level "Info" -Component "CONFIG"
    
    try {
        if (Get-Command notepad -ErrorAction SilentlyContinue) {
            Write-UPMLog -Message "Opening configuration in notepad" -Level "Info" -Component "CONFIG"
            Start-Process notepad -ArgumentList $script:DefaultConfigPath -Wait
        } else {
            Write-UPMLog -Message "Notepad not available, configuration file: $script:DefaultConfigPath" -Level "Info" -Component "CONFIG"
        }
    }
    catch {
        Write-UPMLog -Message "Failed to open configuration editor: $($_.Exception.Message)" -Level "Error" -Component "CONFIG"
    }
}

# Main execution
try {
    # Initialize system
    $config = Initialize-UPM
    
    # Execute requested operation
    switch ($Operation) {
        "Update" {
            Invoke-UpdateOperation -Config $config
        }
        "Status" {
            Invoke-StatusOperation -Config $config
        }
        "Configure" {
            Invoke-ConfigureOperation -Config $config
        }
        default {
            Write-UPMLog -Message "Unknown operation: $Operation" -Level "Error" -Component "MAIN"
            exit 1
        }
    }
    
    Write-UPMLog -Message "Universal Package Manager v3.0 completed successfully" -Level "Success" -Component "MAIN"
    exit 0
}
catch {
    Write-UPMLog -Message "Universal Package Manager failed: $($_.Exception.Message)" -Level "Error" -Component "MAIN"
    Write-Error $_.Exception.ToString()
    exit 1
}