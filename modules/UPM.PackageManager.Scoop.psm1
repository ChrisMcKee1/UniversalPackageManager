#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Scoop Package Manager Module
.DESCRIPTION
    Handles Scoop package manager operations with PowerShell 7+ features.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1
using module ./UPM.ProcessExecution.psm1

function Test-ScoopAvailable {
    [CmdletBinding()]
    param()
    
    $result = Test-UPMCommand -Command "scoop" -Arguments "help"
    
    if ($result.Available) {
        Write-UPMLog -Message "Scoop is available at: $($result.Path)" -Level "Success" -Component "SCOOP"
    } else {
        Write-UPMLog -Message "Scoop is not available: $($result.Error)" -Level "Warning" -Component "SCOOP"
    }
    
    return $result
}

function Update-ScoopPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $operation = if ($DryRun) { "status check" } else { "update" }
    Write-UPMLog -Message "Starting Scoop $operation" -Level "Debug" -Component "SCOOP"
    
    try {
        if ($DryRun) {
            $scoopArgs = "status"
        } else {
            $scoopArgs = "update *"
        }
        
        $result = Invoke-UPMProcess -FilePath "scoop" -Arguments $scoopArgs -TimeoutSeconds $TimeoutSeconds -Component "SCOOP" -Description "Scoop $operation"
        
        if ($result.Success) {
            Write-UPMLog -Message "Scoop $operation completed successfully" -Level "Success" -Component "SCOOP"
        } else {
            Write-UPMLog -Message "Scoop $operation failed (exit code: $($result.ExitCode))" -Level "Error" -Component "SCOOP"
        }
        
        return @{
            Success = $result.Success
            ExitCode = $result.ExitCode
            Duration = $result.Duration
            TimedOut = $result.TimedOut
            Operation = $operation
            PackageManager = "scoop"
        }
    }
    catch {
        Write-UPMLog -Message "Scoop $operation error: $($_.Exception.Message)" -Level "Error" -Component "SCOOP"
        return @{
            Success = $false
            ExitCode = -1
            Duration = [TimeSpan]::Zero
            TimedOut = $false
            Operation = $operation
            PackageManager = "scoop"
            Error = $_.Exception.Message
        }
    }
}

function Get-ScoopInfo {
    [CmdletBinding()]
    param()
    
    try {
        $availability = Test-ScoopAvailable
        
        if (-not $availability.Available) {
            return @{
                Available = $false
                Error = $availability.Error
                PackageManager = "scoop"
            }
        }
        
        return @{
            Available = $true
            Path = $availability.Path
            Version = "Available"
            PackageManager = "scoop"
            Description = "Command-line installer for Windows"
        }
    }
    catch {
        return @{
            Available = $false
            Error = $_.Exception.Message
            PackageManager = "scoop"
        }
    }
}

Export-ModuleMember -Function @(
    'Test-ScoopAvailable',
    'Update-ScoopPackages',
    'Get-ScoopInfo'
)