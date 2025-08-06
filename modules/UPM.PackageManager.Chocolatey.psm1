#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Chocolatey Package Manager Module
.DESCRIPTION
    Handles Chocolatey package manager operations including updates,
    listing packages, and status checking with modern PowerShell 7+ features.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1
using module ./UPM.ProcessExecution.psm1

function Test-ChocolateyAvailable {
    <#
    .SYNOPSIS
        Check if Chocolatey is available and functional
    #>
    [CmdletBinding()]
    param()
    
    $result = Test-UPMCommand -Command "choco" -Arguments "--version"
    
    if ($result.Available) {
        Write-UPMLog -Message "Chocolatey is available at: $($result.Path)" -Level "Success" -Component "CHOCO"
    } else {
        Write-UPMLog -Message "Chocolatey is not available: $($result.Error)" -Level "Warning" -Component "CHOCO"
    }
    
    return $result
}

function Get-ChocolateyPackages {
    <#
    .SYNOPSIS
        Get list of installed packages from Chocolatey
    .PARAMETER IncludeVersions
        Include version information in the results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeVersions
    )
    
    Write-UPMLog -Message "Retrieving Chocolatey package list" -Level "Info" -Component "CHOCO"
    
    try {
        $arguments = "list --local-only --limit-output"
        if (-not $IncludeVersions) {
            $arguments += " --id-only"
        }
        
        $result = Invoke-UPMProcess -FilePath "choco" -Arguments $arguments -TimeoutSeconds 120 -Component "CHOCO" -Description "Get Chocolatey packages"
        
        if (-not $result.Success) {
            Write-UPMLog -Message "Failed to get Chocolatey packages (exit code: $($result.ExitCode))" -Level "Error" -Component "CHOCO"
            return @()
        }
        
        Write-UPMLog -Message "Successfully retrieved Chocolatey package list" -Level "Success" -Component "CHOCO"
        
        return @{
            Success = $true
            Command = "choco list"
            Duration = $result.Duration
        }
    }
    catch {
        Write-UPMLog -Message "Error getting Chocolatey packages: $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        return @()
    }
}

function Get-ChocolateyUpgradablePackages {
    <#
    .SYNOPSIS
        Get list of packages that can be upgraded via Chocolatey
    #>
    [CmdletBinding()]
    param()
    
    Write-UPMLog -Message "Checking for Chocolatey package upgrades" -Level "Info" -Component "CHOCO"
    
    try {
        $result = Invoke-UPMProcess -FilePath "choco" -Arguments "outdated --limit-output" -TimeoutSeconds 180 -Component "CHOCO" -Description "Check Chocolatey upgrades"
        
        if (-not $result.Success) {
            Write-UPMLog -Message "Failed to check Chocolatey upgrades (exit code: $($result.ExitCode))" -Level "Error" -Component "CHOCO"
            return @()
        }
        
        Write-UPMLog -Message "Successfully checked Chocolatey upgrades" -Level "Success" -Component "CHOCO"
        
        return @{
            Success = $true
            Command = "choco outdated"
            Duration = $result.Duration
        }
    }
    catch {
        Write-UPMLog -Message "Error checking Chocolatey upgrades: $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        return @()
    }
}

function Update-ChocolateyPackages {
    <#
    .SYNOPSIS
        Update all packages using Chocolatey
    .PARAMETER Arguments
        Additional arguments for choco upgrade
    .PARAMETER TimeoutSeconds
        Timeout for the upgrade operation
    .PARAMETER DryRun
        Show what would be updated without making changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "-y --limit-output",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 900,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $operation = if ($DryRun) { "dry-run check" } else { "update" }
    Write-UPMLog -Message "Starting Chocolatey $operation" -Level "Debug" -Component "CHOCO"
    
    try {
        # Build command arguments
        if ($DryRun) {
            # For dry run, we check what's outdated
            $chocoArgs = "outdated --limit-output"
        } else {
            $chocoArgs = "upgrade all $Arguments"
        }
        
        Write-UPMLog -Message "Executing: choco $chocoArgs" -Level "Debug" -Component "CHOCO"
        
        $result = Invoke-UPMProcess -FilePath "choco" -Arguments $chocoArgs -TimeoutSeconds $TimeoutSeconds -Component "CHOCO" -Description "Chocolatey $operation"
        
        if ($result.Success) {
            Write-UPMLog -Message "Chocolatey $operation completed successfully" -Level "Success" -Component "CHOCO" -Data @{
                "Duration" = $result.Duration.TotalSeconds
                "ExitCode" = $result.ExitCode
                "DryRun" = $DryRun.IsPresent
            }
        } else {
            Write-UPMLog -Message "Chocolatey $operation failed (exit code: $($result.ExitCode))" -Level "Error" -Component "CHOCO" -Data @{
                "Duration" = $result.Duration.TotalSeconds
                "ExitCode" = $result.ExitCode
                "TimedOut" = $result.TimedOut
            }
        }
        
        return @{
            Success = $result.Success
            ExitCode = $result.ExitCode
            Duration = $result.Duration
            TimedOut = $result.TimedOut
            Operation = $operation
            PackageManager = "chocolatey"
        }
    }
    catch {
        Write-UPMLog -Message "Chocolatey $operation error: $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        
        return @{
            Success = $false
            ExitCode = -1
            Duration = [TimeSpan]::Zero
            TimedOut = $false
            Operation = $operation
            PackageManager = "chocolatey"
            Error = $_.Exception.Message
        }
    }
}

function Install-ChocolateyPackage {
    <#
    .SYNOPSIS
        Install a specific package using Chocolatey
    .PARAMETER PackageId
        Package identifier to install
    .PARAMETER Arguments
        Additional arguments for choco install
    .PARAMETER TimeoutSeconds
        Timeout for the installation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "-y --limit-output",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600
    )
    
    Write-UPMLog -Message "Installing package: $PackageId" -Level "Info" -Component "CHOCO"
    
    try {
        $chocoArgs = "install $PackageId $Arguments"
        
        $result = Invoke-UPMProcess -FilePath "choco" -Arguments $chocoArgs -TimeoutSeconds $TimeoutSeconds -Component "CHOCO" -Description "Install $PackageId"
        
        if ($result.Success) {
            Write-UPMLog -Message "Package installed successfully: $PackageId" -Level "Success" -Component "CHOCO"
        } else {
            Write-UPMLog -Message "Package installation failed: $PackageId (exit code: $($result.ExitCode))" -Level "Error" -Component "CHOCO"
        }
        
        return $result
    }
    catch {
        Write-UPMLog -Message "Error installing package '$PackageId': $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        throw
    }
}

function Uninstall-ChocolateyPackage {
    <#
    .SYNOPSIS
        Uninstall a specific package using Chocolatey
    .PARAMETER PackageId
        Package identifier to uninstall
    .PARAMETER Arguments
        Additional arguments for choco uninstall
    .PARAMETER TimeoutSeconds
        Timeout for the uninstallation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "-y --limit-output --remove-dependencies",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )
    
    Write-UPMLog -Message "Uninstalling package: $PackageId" -Level "Info" -Component "CHOCO"
    
    try {
        $chocoArgs = "uninstall $PackageId $Arguments"
        
        $result = Invoke-UPMProcess -FilePath "choco" -Arguments $chocoArgs -TimeoutSeconds $TimeoutSeconds -Component "CHOCO" -Description "Uninstall $PackageId"
        
        if ($result.Success) {
            Write-UPMLog -Message "Package uninstalled successfully: $PackageId" -Level "Success" -Component "CHOCO"
        } else {
            Write-UPMLog -Message "Package uninstallation failed: $PackageId (exit code: $($result.ExitCode))" -Level "Error" -Component "CHOCO"
        }
        
        return $result
    }
    catch {
        Write-UPMLog -Message "Error uninstalling package '$PackageId': $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        throw
    }
}

function Update-ChocolateyItself {
    <#
    .SYNOPSIS
        Update Chocolatey itself to the latest version
    .PARAMETER TimeoutSeconds
        Timeout for the upgrade operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )
    
    Write-UPMLog -Message "Updating Chocolatey itself" -Level "Info" -Component "CHOCO"
    
    try {
        $result = Invoke-UPMProcess -FilePath "choco" -Arguments "upgrade chocolatey -y --limit-output" -TimeoutSeconds $TimeoutSeconds -Component "CHOCO" -Description "Update Chocolatey"
        
        if ($result.Success) {
            Write-UPMLog -Message "Chocolatey updated successfully" -Level "Success" -Component "CHOCO"
        } else {
            Write-UPMLog -Message "Chocolatey update failed (exit code: $($result.ExitCode))" -Level "Error" -Component "CHOCO"
        }
        
        return $result
    }
    catch {
        Write-UPMLog -Message "Error updating Chocolatey: $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        throw
    }
}

function Get-ChocolateyInfo {
    <#
    .SYNOPSIS
        Get information about Chocolatey installation and configuration
    #>
    [CmdletBinding()]
    param()
    
    try {
        $availability = Test-ChocolateyAvailable
        
        if (-not $availability.Available) {
            return @{
                Available = $false
                Error = $availability.Error
                PackageManager = "chocolatey"
            }
        }
        
        # Get Chocolatey version info
        $versionResult = Invoke-UPMProcess -FilePath "choco" -Arguments "--version" -TimeoutSeconds 30 -Component "CHOCO"
        
        return @{
            Available = $true
            Path = $availability.Path
            Version = if ($versionResult.Success) { "Available" } else { "Unknown" }
            PackageManager = "chocolatey"
            Description = "Popular Windows package manager"
        }
    }
    catch {
        Write-UPMLog -Message "Error getting Chocolatey info: $($_.Exception.Message)" -Level "Warning" -Component "CHOCO"
        return @{
            Available = $false
            Error = $_.Exception.Message
            PackageManager = "chocolatey"
        }
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Test-ChocolateyAvailable',
    'Get-ChocolateyPackages',
    'Get-ChocolateyUpgradablePackages',
    'Update-ChocolateyPackages',
    'Install-ChocolateyPackage',
    'Uninstall-ChocolateyPackage',
    'Update-ChocolateyItself',
    'Get-ChocolateyInfo'
)