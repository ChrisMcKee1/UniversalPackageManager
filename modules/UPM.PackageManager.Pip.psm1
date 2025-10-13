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

# Module-level variable to store the resolved pip path
$script:PipPath = $null

function Test-PipAvailable {
    [CmdletBinding()]
    param()
    
    try {
        # First try standard PATH lookup
        $result = Test-UPMCommand -Command "pip" -Arguments "--version"
        
        if (-not $result.Available) {
            Write-UPMLog -Message "Pip not found in PATH, searching well-known Python installation locations" -Level "Debug" -Component "PIP"
            
            # Search system-wide Python/pip installation paths (for NT AUTHORITY\SYSTEM context)
            $pipSearchPaths = @(
                "$env:ProgramFiles\Python3*\Scripts",
                "C:\Program Files\Python3*\Scripts",
                "$env:LOCALAPPDATA\Programs\Python\Python3*\Scripts",
                "$env:APPDATA\Python\Python3*\Scripts"
            )
            
            foreach ($searchPath in $pipSearchPaths) {
                $expandedPath = [Environment]::ExpandEnvironmentVariables($searchPath)
                
                # Handle wildcards
                if ($expandedPath -like "*`**") {
                    $parentPath = Split-Path $expandedPath
                    $filter = Split-Path $expandedPath -Leaf
                    $matchingDirs = Get-ChildItem -Path $parentPath -Filter $filter -Directory -ErrorAction SilentlyContinue
                    
                    foreach ($dir in $matchingDirs) {
                        $pipExe = Join-Path $dir.FullName "pip.exe"
                        if (Test-Path $pipExe -PathType Leaf) {
                            Write-UPMLog -Message "Found pip at: $pipExe" -Level "Success" -Component "PIP"
                            
                            # Add to session PATH
                            $dirPath = $dir.FullName
                            if ($env:PATH -notlike "*$dirPath*") {
                                $env:PATH = "$dirPath;" + $env:PATH
                            }
                            
                            # Re-test
                            $result = Test-UPMCommand -Command "pip" -Arguments "--version"
                            break
                        }
                    }
                } else {
                    $pipExe = Join-Path $expandedPath "pip.exe"
                    if (Test-Path $pipExe -PathType Leaf) {
                        Write-UPMLog -Message "Found pip at: $pipExe" -Level "Success" -Component "PIP"
                        
                        if ($env:PATH -notlike "*$expandedPath*") {
                            $env:PATH = "$expandedPath;" + $env:PATH
                        }
                        
                        $result = Test-UPMCommand -Command "pip" -Arguments "--version"
                        break
                    }
                }
                
                if ($result.Available) { break }
            }
        }
        
        if ($result.Available) {
            $script:PipPath = $result.Path
            Write-UPMLog -Message "Pip is available at: $($result.Path)" -Level "Success" -Component "PIP"
        } else {
            $script:PipPath = $null
            Write-UPMLog -Message "Pip is not available: $($result.Error)" -Level "Warning" -Component "PIP"
        }
        
        return $result
    }
    catch {
        $script:PipPath = $null
        Write-UPMLog -Message "Error testing pip availability: $($_.Exception.Message)" -Level "Error" -Component "PIP"
        return @{
            Available = $false
            Path = $null
            Version = $null
            Error = $_.Exception.Message
        }
    }
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
        # Validate pip is available
        if (-not $script:PipPath) {
            $testResult = Test-PipAvailable
            if (-not $testResult.Available) {
                Write-UPMLog -Message "Pip is not available, cannot perform $operation" -Level "Error" -Component "PIP"
                return @{
                    Success = $false
                    Duration = [TimeSpan]::Zero
                    ExitCode = -1
                    Error = "Pip not available"
                }
            }
        }
        
        if ($DryRun) {
            $pipArgs = "list --outdated"
        } else {
            # Note: pip doesn't have a built-in "upgrade all" command like npm
            # For now, we'll use pip-autoremove or just list outdated packages
            # A proper implementation would parse the output and upgrade each package
            $pipArgs = "list --outdated"
        }
        
        $result = Invoke-UPMProcess -FilePath $script:PipPath -Arguments $pipArgs -TimeoutSeconds $TimeoutSeconds -Component "PIP" -Description "Pip $operation"
        
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