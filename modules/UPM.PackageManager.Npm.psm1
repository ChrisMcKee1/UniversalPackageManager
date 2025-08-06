#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - NPM Package Manager Module
.DESCRIPTION
    Handles NPM global package operations with PowerShell 7+ features.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1
using module ./UPM.ProcessExecution.psm1

function Test-NpmAvailable {
    [CmdletBinding()]
    param()
    
    $result = Test-UPMCommand -Command "npm" -Arguments "--version"
    
    if ($result.Available) {
        Write-UPMLog -Message "NPM is available at: $($result.Path)" -Level "Success" -Component "NPM"
    } else {
        Write-UPMLog -Message "NPM is not available: $($result.Error)" -Level "Warning" -Component "NPM"
    }
    
    return $result
}

function Update-NpmPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $operation = if ($DryRun) { "outdated check" } else { "update" }
    Write-UPMLog -Message "Starting NPM global $operation" -Level "Debug" -Component "NPM"
    
    try {
        if ($DryRun) {
            $npmArgs = "outdated -g --depth=0"
        } else {
            $npmArgs = "update -g"
        }
        
        $result = Invoke-UPMProcess -FilePath "npm" -Arguments $npmArgs -TimeoutSeconds $TimeoutSeconds -Component "NPM" -Description "NPM global $operation"
        
        # For npm outdated, exit code 1 is normal when packages are outdated (not an error)
        $isSuccess = $result.Success -or ($DryRun -and $result.ExitCode -eq 1)
        
        if ($isSuccess) {
            Write-UPMLog -Message "NPM global $operation completed successfully" -Level "Success" -Component "NPM"
        } else {
            Write-UPMLog -Message "NPM global $operation failed (exit code: $($result.ExitCode))" -Level "Error" -Component "NPM"
        }
        
        return @{
            Success = $isSuccess
            ExitCode = $result.ExitCode
            Duration = $result.Duration
            TimedOut = $result.TimedOut
            Operation = $operation
            PackageManager = "npm"
        }
    }
    catch {
        Write-UPMLog -Message "NPM global $operation error: $($_.Exception.Message)" -Level "Error" -Component "NPM"
        return @{
            Success = $false
            ExitCode = -1
            Duration = [TimeSpan]::Zero
            TimedOut = $false
            Operation = $operation
            PackageManager = "npm"
            Error = $_.Exception.Message
        }
    }
}

function Get-NpmInfo {
    [CmdletBinding()]
    param()
    
    try {
        $availability = Test-NpmAvailable
        
        if (-not $availability.Available) {
            return @{
                Available = $false
                Error = $availability.Error
                PackageManager = "npm"
            }
        }
        
        return @{
            Available = $true
            Path = $availability.Path
            Version = "Available"
            PackageManager = "npm"
            Description = "Node.js package manager (global packages)"
        }
    }
    catch {
        return @{
            Available = $false
            Error = $_.Exception.Message
            PackageManager = "npm"
        }
    }
}

Export-ModuleMember -Function @(
    'Test-NpmAvailable',
    'Update-NpmPackages', 
    'Get-NpmInfo'
)