#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Pip Package Manager Module
.DESCRIPTION
    Handles Python pip package operations with PowerShell 7+ features.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1
using module ./UPM.ProcessExecution.psm1

function Test-PipAvailable {
    [CmdletBinding()]
    param()
    
    $result = Test-UPMCommand -Command "pip" -Arguments "--version"
    
    if ($result.Available) {
        Write-UPMLog -Message "Pip is available at: $($result.Path)" -Level "Success" -Component "PIP"
    } else {
        Write-UPMLog -Message "Pip is not available: $($result.Error)" -Level "Warning" -Component "PIP"
    }
    
    return $result
}

function Update-PipPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "--quiet",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $operation = if ($DryRun) { "outdated check" } else { "update" }
    Write-UPMLog -Message "Starting Pip $operation" -Level "Debug" -Component "PIP"
    
    try {
        if ($DryRun) {
            $pipArgs = "list --outdated"
        } else {
            # Note: pip doesn't have a built-in "upgrade all" command like npm
            # For now, we'll use pip-autoremove or just list outdated packages
            # A proper implementation would parse the output and upgrade each package
            $pipArgs = "list --outdated"
        }
        
        $result = Invoke-UPMProcess -FilePath "pip" -Arguments $pipArgs -TimeoutSeconds $TimeoutSeconds -Component "PIP" -Description "Pip $operation"
        
        if ($result.Success) {
            Write-UPMLog -Message "Pip $operation completed successfully" -Level "Success" -Component "PIP"
        } else {
            Write-UPMLog -Message "Pip $operation failed (exit code: $($result.ExitCode))" -Level "Error" -Component "PIP"
        }
        
        return @{
            Success = $result.Success
            ExitCode = $result.ExitCode
            Duration = $result.Duration
            TimedOut = $result.TimedOut
            Operation = $operation
            PackageManager = "pip"
        }
    }
    catch {
        Write-UPMLog -Message "Pip $operation error: $($_.Exception.Message)" -Level "Error" -Component "PIP"
        return @{
            Success = $false
            ExitCode = -1
            Duration = [TimeSpan]::Zero
            TimedOut = $false
            Operation = $operation
            PackageManager = "pip"
            Error = $_.Exception.Message
        }
    }
}

function Get-PipInfo {
    [CmdletBinding()]
    param()
    
    try {
        $availability = Test-PipAvailable
        
        if (-not $availability.Available) {
            return @{
                Available = $false
                Error = $availability.Error
                PackageManager = "pip"
            }
        }
        
        return @{
            Available = $true
            Path = $availability.Path
            Version = "Available"
            PackageManager = "pip"
            Description = "Python package installer"
        }
    }
    catch {
        return @{
            Available = $false
            Error = $_.Exception.Message
            PackageManager = "pip"
        }
    }
}

Export-ModuleMember -Function @(
    'Test-PipAvailable',
    'Update-PipPackages',
    'Get-PipInfo'
)