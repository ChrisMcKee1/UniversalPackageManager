#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Conda Package Manager Module
.DESCRIPTION
    Handles Conda package operations with PowerShell 7+ features.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1
using module ./UPM.ProcessExecution.psm1

function Test-CondaAvailable {
    [CmdletBinding()]
    param()
    
    # First try standard command lookup
    $result = Test-UPMCommand -Command "conda" -Arguments "--version"
    
    if (-not $result.Available) {
        Write-UPMLog -Message "Conda not found in PATH, searching common installation locations" -Level "Debug" -Component "CONDA"
        
        # Search common conda installation paths
        $condaSearchPaths = @(
            "$env:USERPROFILE\AppData\Local\miniconda3\Scripts",
            "$env:LOCALAPPDATA\miniconda3\Scripts",
            "C:\miniconda3\Scripts",
            "$env:PROGRAMFILES\Miniconda3\Scripts",
            "$env:PROGRAMFILES(X86)\Miniconda3\Scripts",
            "$env:USERPROFILE\Anaconda3\Scripts",
            "$env:PROGRAMFILES\Anaconda3\Scripts"
        )
        
        foreach ($searchPath in $condaSearchPaths) {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($searchPath)
            $condaExe = Join-Path $expandedPath "conda.exe"
            
            if (Test-Path $condaExe -PathType Leaf) {
                Write-UPMLog -Message "Found conda installation at: $condaExe" -Level "Success" -Component "CONDA"
                
                # Add to current session PATH
                if ($env:PATH -notlike "*$expandedPath*") {
                    $env:PATH = "$expandedPath;" + $env:PATH
                    Write-UPMLog -Message "Added conda to session PATH: $expandedPath" -Level "Info" -Component "CONDA"
                }
                
                # Test again with updated PATH
                $result = Test-UPMCommand -Command "conda" -Arguments "--version"
                break
            }
        }
    }
    
    if ($result.Available) {
        Write-UPMLog -Message "Conda is available at: $($result.Path)" -Level "Success" -Component "CONDA"
    } else {
        Write-UPMLog -Message "Conda is not available: $($result.Error)" -Level "Warning" -Component "CONDA"
    }
    
    return $result
}

function Update-CondaPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "-y --quiet",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 900,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $operation = if ($DryRun) { "list check" } else { "update" }
    Write-UPMLog -Message "Starting Conda $operation" -Level "Debug" -Component "CONDA"
    
    try {
        # First, ensure conda is configured for non-interactive use
        Write-UPMLog -Message "Ensuring conda non-interactive configuration" -Level "Debug" -Component "CONDA"
        
        # Accept Terms of Service for common channels non-interactively
        $tosChannels = @(
            "https://repo.anaconda.com/pkgs/main",
            "https://repo.anaconda.com/pkgs/r", 
            "https://repo.anaconda.com/pkgs/msys2"
        )
        
        foreach ($channel in $tosChannels) {
            Write-UPMLog -Message "Accepting Terms of Service for: $channel" -Level "Debug" -Component "CONDA"
            $tosResult = Invoke-UPMProcess -FilePath "conda" -Arguments "tos accept --override-channels --channel $channel" -TimeoutSeconds 60 -Component "CONDA" -Description "Accept conda TOS"
            # Don't fail if TOS acceptance fails (might already be accepted)
            if (-not $tosResult.Success) {
                Write-UPMLog -Message "TOS acceptance failed for $channel (might already be accepted)" -Level "Debug" -Component "CONDA"
            }
        }
        
        # Configure conda for non-interactive use
        Write-UPMLog -Message "Configuring conda for non-interactive use" -Level "Debug" -Component "CONDA"
        $configResult = Invoke-UPMProcess -FilePath "conda" -Arguments "config --set always_yes true" -TimeoutSeconds 60 -Component "CONDA" -Description "Configure conda non-interactive"
        
        if ($DryRun) {
            $condaArgs = "list --name base"
        } else {
            # Use --yes flag to ensure non-interactive operation
            $condaArgs = "update --all --yes --quiet"
            if ($Arguments -and $Arguments -notlike "*--yes*") {
                $condaArgs = "update --all --yes $Arguments"
            }
        }
        
        $result = Invoke-UPMProcess -FilePath "conda" -Arguments $condaArgs -TimeoutSeconds $TimeoutSeconds -Component "CONDA" -Description "Conda $operation"
        
        if ($result.Success) {
            Write-UPMLog -Message "Conda $operation completed successfully" -Level "Success" -Component "CONDA"
        } else {
            Write-UPMLog -Message "Conda $operation failed (exit code: $($result.ExitCode))" -Level "Error" -Component "CONDA"
        }
        
        return @{
            Success = $result.Success
            ExitCode = $result.ExitCode
            Duration = $result.Duration
            TimedOut = $result.TimedOut
            Operation = $operation
            PackageManager = "conda"
        }
    }
    catch {
        Write-UPMLog -Message "Conda $operation error: $($_.Exception.Message)" -Level "Error" -Component "CONDA"
        return @{
            Success = $false
            ExitCode = -1
            Duration = [TimeSpan]::Zero
            TimedOut = $false
            Operation = $operation
            PackageManager = "conda"
            Error = $_.Exception.Message
        }
    }
}

function Get-CondaInfo {
    [CmdletBinding()]
    param()
    
    try {
        $availability = Test-CondaAvailable
        
        if (-not $availability.Available) {
            return @{
                Available = $false
                Error = $availability.Error
                PackageManager = "conda"
            }
        }
        
        return @{
            Available = $true
            Path = $availability.Path
            Version = "Available"
            PackageManager = "conda"
            Description = "Python/R data science package manager"
        }
    }
    catch {
        return @{
            Available = $false
            Error = $_.Exception.Message
            PackageManager = "conda"
        }
    }
}

Export-ModuleMember -Function @(
    'Test-CondaAvailable',
    'Update-CondaPackages',
    'Get-CondaInfo'
)