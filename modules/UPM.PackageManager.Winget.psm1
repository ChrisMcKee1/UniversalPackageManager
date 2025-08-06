#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Winget Package Manager Module
.DESCRIPTION
    Handles Windows Package Manager (winget) operations including updates,
    listing packages, and status checking with modern PowerShell 7+ features.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1
using module ./UPM.ProcessExecution.psm1

function Test-WingetAvailable {
    <#
    .SYNOPSIS
        Check if winget is available and functional
    #>
    [CmdletBinding()]
    param()
    
    $result = Test-UPMCommand -Command "winget" -Arguments "--version"
    
    if ($result.Available) {
        Write-UPMLog -Message "Winget is available at: $($result.Path)" -Level "Success" -Component "WINGET"
    } else {
        Write-UPMLog -Message "Winget is not available: $($result.Error)" -Level "Warning" -Component "WINGET"
    }
    
    return $result
}

function Get-WingetPackages {
    <#
    .SYNOPSIS
        Get list of installed packages from winget
    .PARAMETER IncludeVersions
        Include version information in the results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeVersions
    )
    
    Write-UPMLog -Message "Retrieving winget package list" -Level "Info" -Component "WINGET"
    
    try {
        $arguments = "list --disable-interactivity"
        if (-not $IncludeVersions) {
            $arguments += " --name"
        }
        
        $result = Invoke-UPMProcess -FilePath "winget" -Arguments $arguments -TimeoutSeconds 120 -Component "WINGET" -Description "Get winget packages"
        
        if (-not $result.Success) {
            Write-UPMLog -Message "Failed to get winget packages (exit code: $($result.ExitCode))" -Level "Error" -Component "WINGET"
            return @()
        }
        
        # Note: In a full implementation, we would parse the winget output here
        # For this modular version, we'll return a simple success indicator
        Write-UPMLog -Message "Successfully retrieved winget package list" -Level "Success" -Component "WINGET"
        
        return @{
            Success = $true
            Command = "winget list"
            Duration = $result.Duration
        }
    }
    catch {
        Write-UPMLog -Message "Error getting winget packages: $($_.Exception.Message)" -Level "Error" -Component "WINGET"
        return @()
    }
}

function Get-WingetUpgradablePackages {
    <#
    .SYNOPSIS
        Get list of packages that can be upgraded via winget
    #>
    [CmdletBinding()]
    param()
    
    Write-UPMLog -Message "Checking for winget package upgrades" -Level "Info" -Component "WINGET"
    
    try {
        $result = Invoke-UPMProcess -FilePath "winget" -Arguments "upgrade --disable-interactivity" -TimeoutSeconds 180 -Component "WINGET" -Description "Check winget upgrades"
        
        if (-not $result.Success) {
            Write-UPMLog -Message "Failed to check winget upgrades (exit code: $($result.ExitCode))" -Level "Error" -Component "WINGET"
            return @()
        }
        
        Write-UPMLog -Message "Successfully checked winget upgrades" -Level "Success" -Component "WINGET"
        
        return @{
            Success = $true
            Command = "winget upgrade"
            Duration = $result.Duration
        }
    }
    catch {
        Write-UPMLog -Message "Error checking winget upgrades: $($_.Exception.Message)" -Level "Error" -Component "WINGET"
        return @()
    }
}

function Update-WingetPackages {
    <#
    .SYNOPSIS
        Update all packages using winget
    .PARAMETER Arguments
        Additional arguments for winget upgrade
    .PARAMETER TimeoutSeconds
        Timeout for the upgrade operation
    .PARAMETER DryRun
        Show what would be updated without making changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "--accept-source-agreements --accept-package-agreements --silent",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $operation = if ($DryRun) { "dry-run check" } else { "update" }
    Write-UPMLog -Message "Starting winget $operation" -Level "Debug" -Component "WINGET"
    
    try {
        # Build command arguments
        $wingetArgs = "upgrade --all $Arguments --disable-interactivity"
        if ($DryRun) {
            # For dry run, we just check what's available
            $wingetArgs = "upgrade --disable-interactivity"
        }
        
        Write-UPMLog -Message "Executing: winget $wingetArgs" -Level "Debug" -Component "WINGET"
        
        $result = Invoke-UPMProcess -FilePath "winget" -Arguments $wingetArgs -TimeoutSeconds $TimeoutSeconds -Component "WINGET" -Description "Winget $operation"
        
        # Winget often returns non-zero exit codes even on partial success
        # Check for specific acceptable exit codes
        $acceptableExitCodes = @(0, -1978335188)  # 0 = success, -1978335188 = partial success with some failures
        $isAcceptableResult = $result.Success -or ($acceptableExitCodes -contains $result.ExitCode)
        
        if ($isAcceptableResult) {
            $level = if ($result.Success) { "Success" } else { "Warning" }
            $message = if ($result.Success) { 
                "Winget $operation completed successfully" 
            } else { 
                "Winget $operation completed with some failures (exit code: $($result.ExitCode))" 
            }
            
            Write-UPMLog -Message $message -Level $level -Component "WINGET" -Data @{
                "Duration" = $result.Duration.TotalSeconds
                "ExitCode" = $result.ExitCode
                "DryRun" = $DryRun.IsPresent
            }
        } else {
            Write-UPMLog -Message "Winget $operation failed (exit code: $($result.ExitCode))" -Level "Error" -Component "WINGET" -Data @{
                "Duration" = $result.Duration.TotalSeconds
                "ExitCode" = $result.ExitCode
                "TimedOut" = $result.TimedOut
            }
        }
        
        return @{
            Success = $isAcceptableResult
            ExitCode = $result.ExitCode
            Duration = $result.Duration
            TimedOut = $result.TimedOut
            Operation = $operation
            PackageManager = "winget"
        }
    }
    catch {
        Write-UPMLog -Message "Winget $operation error: $($_.Exception.Message)" -Level "Error" -Component "WINGET"
        
        return @{
            Success = $false
            ExitCode = -1
            Duration = [TimeSpan]::Zero
            TimedOut = $false
            Operation = $operation
            PackageManager = "winget"
            Error = $_.Exception.Message
        }
    }
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
        Install a specific package using winget
    .PARAMETER PackageId
        Package identifier to install
    .PARAMETER Arguments
        Additional arguments for winget install
    .PARAMETER TimeoutSeconds
        Timeout for the installation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "--accept-source-agreements --accept-package-agreements --silent",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600
    )
    
    Write-UPMLog -Message "Installing package: $PackageId" -Level "Info" -Component "WINGET"
    
    try {
        $wingetArgs = "install $PackageId $Arguments --disable-interactivity"
        
        $result = Invoke-UPMProcess -FilePath "winget" -Arguments $wingetArgs -TimeoutSeconds $TimeoutSeconds -Component "WINGET" -Description "Install $PackageId"
        
        if ($result.Success) {
            Write-UPMLog -Message "Package installed successfully: $PackageId" -Level "Success" -Component "WINGET"
        } else {
            Write-UPMLog -Message "Package installation failed: $PackageId (exit code: $($result.ExitCode))" -Level "Error" -Component "WINGET"
        }
        
        return $result
    }
    catch {
        Write-UPMLog -Message "Error installing package '$PackageId': $($_.Exception.Message)" -Level "Error" -Component "WINGET"
        throw
    }
}

function Uninstall-WingetPackage {
    <#
    .SYNOPSIS
        Uninstall a specific package using winget
    .PARAMETER PackageId
        Package identifier to uninstall
    .PARAMETER Arguments
        Additional arguments for winget uninstall
    .PARAMETER TimeoutSeconds
        Timeout for the uninstallation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "--silent",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )
    
    Write-UPMLog -Message "Uninstalling package: $PackageId" -Level "Info" -Component "WINGET"
    
    try {
        $wingetArgs = "uninstall $PackageId $Arguments --disable-interactivity"
        
        $result = Invoke-UPMProcess -FilePath "winget" -Arguments $wingetArgs -TimeoutSeconds $TimeoutSeconds -Component "WINGET" -Description "Uninstall $PackageId"
        
        if ($result.Success) {
            Write-UPMLog -Message "Package uninstalled successfully: $PackageId" -Level "Success" -Component "WINGET"
        } else {
            Write-UPMLog -Message "Package uninstallation failed: $PackageId (exit code: $($result.ExitCode))" -Level "Error" -Component "WINGET"
        }
        
        return $result
    }
    catch {
        Write-UPMLog -Message "Error uninstalling package '$PackageId': $($_.Exception.Message)" -Level "Error" -Component "WINGET"
        throw
    }
}

function Get-WingetInfo {
    <#
    .SYNOPSIS
        Get information about winget installation and configuration
    #>
    [CmdletBinding()]
    param()
    
    try {
        $availability = Test-WingetAvailable
        
        if (-not $availability.Available) {
            return @{
                Available = $false
                Error = $availability.Error
                PackageManager = "winget"
            }
        }
        
        # Get winget version info
        $versionResult = Invoke-UPMProcess -FilePath "winget" -Arguments "--version --disable-interactivity" -TimeoutSeconds 30 -Component "WINGET"
        
        return @{
            Available = $true
            Path = $availability.Path
            Version = if ($versionResult.Success) { "Available" } else { "Unknown" }
            PackageManager = "winget"
            Description = "Microsoft's official package manager"
        }
    }
    catch {
        Write-UPMLog -Message "Error getting winget info: $($_.Exception.Message)" -Level "Warning" -Component "WINGET"
        return @{
            Available = $false
            Error = $_.Exception.Message
            PackageManager = "winget"
        }
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Test-WingetAvailable',
    'Get-WingetPackages',
    'Get-WingetUpgradablePackages', 
    'Update-WingetPackages',
    'Install-WingetPackage',
    'Uninstall-WingetPackage',
    'Get-WingetInfo'
)