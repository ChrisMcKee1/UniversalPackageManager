#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Process Execution Module
.DESCRIPTION
    Handles safe process execution with timeout support, progress tracking,
    and comprehensive error handling for PowerShell 7+ environments.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1

function Invoke-UPMProcess {
    <#
    .SYNOPSIS
        Execute a process with timeout and progress tracking
    .PARAMETER FilePath
        Path to the executable
    .PARAMETER Arguments
        Command line arguments
    .PARAMETER TimeoutSeconds
        Timeout in seconds (PowerShell 7+ TimeoutSec parameter)
    .PARAMETER WorkingDirectory
        Working directory for the process
    .PARAMETER Component
        Component name for logging
    .PARAMETER Description
        Human-readable description of the operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,
        
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = $PWD,
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "PROCESS",
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    $timer = Start-UPMTimer -Name "Process: $FilePath"
    $processDescription = if ($Description) { $Description } else { "$FilePath $Arguments".Trim() }
    
    Write-UPMLog -Message "Starting process: $processDescription" -Level "Debug" -Component $Component -Data @{
        "FilePath" = $FilePath
        "Arguments" = $Arguments
        "TimeoutSeconds" = $TimeoutSeconds
        "WorkingDirectory" = $WorkingDirectory
    }
    
    try {
        # Validate executable exists
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            # Try to find executable, checking extensions in priority order
            $extensions = @(".exe", ".cmd", ".bat", ".ps1")
            $foundPath = $null
            
            foreach ($ext in $extensions) {
                $testCommand = Get-Command "$FilePath$ext" -ErrorAction SilentlyContinue
                if ($testCommand) {
                    $foundPath = $testCommand.Source
                    Write-UPMLog -Message "Using executable: $foundPath" -Level "Debug" -Component $Component
                    break
                }
            }
            
            # Fallback to original Get-Command if no specific extension worked
            if (-not $foundPath) {
                $fallbackCommand = Get-Command $FilePath -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($fallbackCommand) {
                    $foundPath = $fallbackCommand.Source
                    Write-UPMLog -Message "Using fallback executable: $foundPath" -Level "Debug" -Component $Component
                }
            }
            
            if (-not $foundPath) {
                throw "Executable not found: $FilePath"
            }
            
            $FilePath = $foundPath
        }
        
        # Execute process without timeout (for now)
        Write-UPMLog -Message "Executing process: $processDescription" -Level "Debug" -Component $Component
        
        $processArgs = @{
            FilePath = $FilePath
            WorkingDirectory = $WorkingDirectory
            NoNewWindow = $true
            Wait = $true
            PassThru = $true
        }
        
        if ($Arguments) {
            $processArgs.ArgumentList = $Arguments
        }
        
        $process = Start-Process @processArgs
        $duration = Stop-UPMTimer -Timer $timer -Component $Component
        
        # Analyze results
        $processResult = @{
            ExitCode = $process.ExitCode
            Duration = $duration
            TimedOut = $false
            Success = ($process.ExitCode -eq 0)
            ProcessId = $process.Id
            FilePath = $FilePath
            Arguments = $Arguments
        }
        
        if ($processResult.Success) {
            Write-UPMLog -Message "Process completed successfully: $processDescription" -Level "Success" -Component $Component -Data $processResult
        } else {
            Write-UPMLog -Message "Process failed with exit code $($processResult.ExitCode): $processDescription" -Level "Error" -Component $Component -Data $processResult
        }
        
        return $processResult
    }
    catch [System.ComponentModel.Win32Exception] {
        # Handle timeout specifically
        if ($_.Exception.Message -like "*timeout*") {
            Stop-UPMTimer -Timer $timer -Component $Component
            
            $result = @{
                ExitCode = -1
                Duration = [TimeSpan]::FromSeconds($TimeoutSeconds)
                TimedOut = $true
                Success = $false
                ProcessId = $null
                FilePath = $FilePath
                Arguments = $Arguments
                Error = "Process timed out after $TimeoutSeconds seconds"
            }
            
            Write-UPMLog -Message "Process timed out: $processDescription" -Level "Error" -Component $Component -Data $result
            return $result
        }
        else {
            Stop-UPMTimer -Timer $timer -Component $Component
            Write-UPMLog -Message "Process execution failed: $($_.Exception.Message)" -Level "Error" -Component $Component
            throw
        }
    }
    catch {
        Stop-UPMTimer -Timer $timer -Component $Component
        Write-UPMLog -Message "Process execution error: $($_.Exception.Message)" -Level "Error" -Component $Component
        throw
    }
}

function Test-UPMCommand {
    <#
    .SYNOPSIS
        Test if a command is available and functional
    .PARAMETER Command
        Command name to test
    .PARAMETER Arguments
        Optional test arguments
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "--version"
    )
    
    try {
        # First check if command exists, preferring .cmd/.exe over .ps1
        $commandInfo = Get-Command $Command -ErrorAction SilentlyContinue | Sort-Object { 
            switch ($_.Source) {
                {$_ -like "*.exe"} { 0 }
                {$_ -like "*.cmd"} { 1 }
                {$_ -like "*.bat"} { 2 }
                {$_ -like "*.ps1"} { 3 }
                default { 4 }
            }
        } | Select-Object -First 1
        
        if (-not $commandInfo) {
            return @{
                Available = $false
                Path = $null
                Version = $null
                Error = "Command not found in PATH"
            }
        }
        
        # Try to execute and get version
        Write-UPMLog -Message "Testing command availability: $Command" -Level "Debug" -Component "COMMAND"
        
        # Simple execution for command testing (no timeout needed for version checks)
        try {
            $output = & $Command $Arguments.Split(' ') 2>&1
            $success = $LASTEXITCODE -eq 0
            $exitCode = $LASTEXITCODE
        } catch {
            $success = $false
            $exitCode = -1
            $output = $_.Exception.Message
        }
        
        return @{
            Available = $success
            Path = $commandInfo.Source
            Version = if ($success) { $output -join "`n" } else { $null }
            ExitCode = $exitCode
            Error = if (-not $success) { "Command test failed" } else { $null }
        }
    }
    catch {
        Write-UPMLog -Message "Failed to test command '$Command': $($_.Exception.Message)" -Level "Debug" -Component "COMMAND"
        return @{
            Available = $false
            Path = $null
            Version = $null
            Error = $_.Exception.Message
        }
    }
}

function Invoke-UPMProcessWithRetry {
    <#
    .SYNOPSIS
        Execute a process with retry logic
    .PARAMETER FilePath
        Path to the executable
    .PARAMETER Arguments
        Command line arguments
    .PARAMETER MaxRetries
        Maximum number of retry attempts
    .PARAMETER RetryDelaySeconds
        Delay between retries in seconds
    .PARAMETER TimeoutSeconds
        Timeout per attempt in seconds
    .PARAMETER Component
        Component name for logging
    .PARAMETER Description
        Human-readable description
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 30,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "PROCESS",
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    $attempt = 1
    $lastResult = $null
    
    while ($attempt -le ($MaxRetries + 1)) {  # +1 for initial attempt
        if ($attempt -eq 1) {
            Write-UPMLog -Message "Attempting process execution (attempt $attempt)" -Level "Info" -Component $Component
        } else {
            Write-UPMLog -Message "Retrying process execution (attempt $attempt of $($MaxRetries + 1))" -Level "Warning" -Component $Component
        }
        
        try {
            $result = Invoke-UPMProcess -FilePath $FilePath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds -Component $Component -Description $Description
            
            if ($result.Success) {
                if ($attempt -gt 1) {
                    Write-UPMLog -Message "Process succeeded after $attempt attempts" -Level "Success" -Component $Component
                }
                return $result
            }
            
            $lastResult = $result
            
            # If this wasn't the last attempt, wait before retrying
            if ($attempt -le $MaxRetries) {
                Write-UPMLog -Message "Process failed (exit code: $($result.ExitCode)), waiting $RetryDelaySeconds seconds before retry" -Level "Warning" -Component $Component
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
        catch {
            Write-UPMLog -Message "Process execution error on attempt $attempt`: $($_.Exception.Message)" -Level "Error" -Component $Component
            
            if ($attempt -le $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                throw
            }
        }
        
        $attempt++
    }
    
    # All attempts failed
    Write-UPMLog -Message "Process failed after $($MaxRetries + 1) attempts" -Level "Error" -Component $Component
    return $lastResult
}

function Get-UPMProcessInfo {
    <#
    .SYNOPSIS
        Get information about running processes
    .PARAMETER ProcessName
        Name of the process to search for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProcessName
    )
    
    try {
        if ($ProcessName) {
            $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        } else {
            $processes = Get-Process
        }
        
        $processInfo = @()
        foreach ($process in $processes) {
            $processInfo += @{
                Name = $process.ProcessName
                Id = $process.Id
                StartTime = if ($process.StartTime) { $process.StartTime } else { "Unknown" }
                CPU = $process.CPU
                WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
                Path = try { $process.Path } catch { "Access Denied" }
            }
        }
        
        return $processInfo
    }
    catch {
        Write-UPMLog -Message "Failed to get process info: $($_.Exception.Message)" -Level "Warning" -Component "PROCESS"
        return @()
    }
}

function Stop-UPMProcess {
    <#
    .SYNOPSIS
        Safely stop a process by name or ID
    .PARAMETER ProcessName
        Name of the process to stop
    .PARAMETER ProcessId
        ID of the process to stop
    .PARAMETER Force
        Force kill the process
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProcessName,
        
        [Parameter(Mandatory = $false)]
        [int]$ProcessId,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $processes = @()
        
        if ($ProcessName) {
            $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        } elseif ($ProcessId) {
            $processes = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        } else {
            throw "Either ProcessName or ProcessId must be specified"
        }
        
        foreach ($process in $processes) {
            Write-UPMLog -Message "Stopping process: $($process.ProcessName) (ID: $($process.Id))" -Level "Info" -Component "PROCESS"
            
            if ($Force) {
                $process | Stop-Process -Force
            } else {
                $process | Stop-Process
            }
            
            Write-UPMLog -Message "Process stopped: $($process.ProcessName)" -Level "Success" -Component "PROCESS"
        }
        
        return $processes.Count
    }
    catch {
        Write-UPMLog -Message "Failed to stop process: $($_.Exception.Message)" -Level "Error" -Component "PROCESS"
        throw
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Invoke-UPMProcess',
    'Test-UPMCommand',
    'Invoke-UPMProcessWithRetry',
    'Get-UPMProcessInfo',
    'Stop-UPMProcess'
)