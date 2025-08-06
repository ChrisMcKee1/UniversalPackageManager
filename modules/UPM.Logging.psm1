#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Logging Module
.DESCRIPTION
    Provides structured logging functionality with JSON output, performance metrics,
    and ANSI color support for PowerShell 7+ environments.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

# Global module variables
$script:LogDirectory = $null
$script:LogLevel = "Info"
$script:EnableJsonLogs = $true
$script:EnableConsoleLogs = $true
$script:SessionId = [guid]::NewGuid().ToString("N")[0..7] -join ""

# Log levels with numeric values for filtering
$script:LogLevels = @{
    "Debug"   = 0
    "Info"    = 1
    "Warning" = 2
    "Error"   = 3
    "Success" = 4
}

function Initialize-UPMLogging {
    <#
    .SYNOPSIS
        Initialize the logging system
    .PARAMETER LogDirectory
        Directory path for log files
    .PARAMETER LogLevel
        Minimum log level to output
    .PARAMETER EnableJsonLogs
        Enable JSON structured logging
    .PARAMETER EnableConsoleLogs
        Enable console output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogDirectory,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Debug", "Info", "Warning", "Error", "Success")]
        [string]$LogLevel = "Info",
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableJsonLogs = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableConsoleLogs = $true
    )
    
    $script:LogDirectory = $LogDirectory
    $script:LogLevel = $LogLevel
    $script:EnableJsonLogs = $EnableJsonLogs
    $script:EnableConsoleLogs = $EnableConsoleLogs
    
    # Ensure log directory exists
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
    
    Write-UPMLog -Message "Logging system initialized" -Level "Info" -Component "LOGGING"
}

function Write-UPMLog {
    <#
    .SYNOPSIS
        Write a log entry with structured data and console output
    .PARAMETER Message
        Log message text
    .PARAMETER Level
        Log level (Debug, Info, Warning, Error, Success)
    .PARAMETER Component
        Component or module name
    .PARAMETER Data
        Additional structured data
    #>
    [CmdletBinding()]
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
    
    # Skip if below configured log level
    if ($script:LogLevels[$Level] -lt $script:LogLevels[$script:LogLevel]) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $processId = $PID
    $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    
    # Create structured log entry
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
        Component = $Component
        ProcessId = $processId
        ThreadId = $threadId
        SessionId = $script:SessionId
        Data = $Data
        MachineName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        PSVersion = $PSVersionTable.PSVersion.ToString()
    }
    
    # Write to JSON log file
    if ($script:EnableJsonLogs -and $script:LogDirectory) {
        Write-JsonLog -LogEntry $logEntry
    }
    
    # Write to console with colors
    if ($script:EnableConsoleLogs) {
        Write-ConsoleLog -LogEntry $logEntry
    }
}

function Write-JsonLog {
    <#
    .SYNOPSIS
        Write structured log entry to JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry
    )
    
    if (-not $script:LogDirectory) {
        return
    }
    
    $dateString = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonLogFile = Join-Path $script:LogDirectory "UPM-$dateString.json.log"
    
    try {
        $jsonString = $LogEntry | ConvertTo-Json -Depth 10 -Compress
        Add-Content -Path $jsonLogFile -Value $jsonString -Encoding UTF8
    }
    catch {
        # Fallback to simple logging if JSON fails
        $simpleMessage = "$($LogEntry.Timestamp) [$($LogEntry.Level)] $($LogEntry.Message)"
        Add-Content -Path $jsonLogFile -Value $simpleMessage -Encoding UTF8
    }
}

function Write-ConsoleLog {
    <#
    .SYNOPSIS
        Write formatted log entry to console with colors
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry
    )
    
    $levelIndicator = switch ($LogEntry.Level) {
        "Debug"   { "DEBUG:" }
        "Info"    { "INFO:" }
        "Warning" { "WARNING:" }
        "Error"   { "ERROR:" }
        "Success" { "SUCCESS:" }
        default   { "LOG:" }
    }
    
    $color = switch ($LogEntry.Level) {
        "Debug"   { $PSStyle.Foreground.Gray }
        "Info"    { $PSStyle.Foreground.White }
        "Warning" { $PSStyle.Foreground.Yellow }
        "Error"   { $PSStyle.Foreground.Red }
        "Success" { $PSStyle.Foreground.Green }
        default   { $PSStyle.Foreground.White }
    }
    
    $timestamp = $LogEntry.Timestamp.Substring(11, 8)  # HH:mm:ss only
    $formattedMessage = "$color[$timestamp] $levelIndicator $($LogEntry.Message)$($PSStyle.Reset)"
    
    Write-Host $formattedMessage
    
    # Show additional data if available and in Debug mode
    if ($LogEntry.Data.Count -gt 0 -and $LogEntry.Level -eq "Debug") {
        foreach ($key in $LogEntry.Data.Keys) {
            Write-Host "  $key = $($LogEntry.Data[$key])" -ForegroundColor Gray
        }
    }
}

function Start-UPMTimer {
    <#
    .SYNOPSIS
        Start a performance timer for operations
    .PARAMETER Name
        Timer name for identification
    .OUTPUTS
        Timer object with Start time
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    return @{
        Name = $Name
        StartTime = Get-Date
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Stop-UPMTimer {
    <#
    .SYNOPSIS
        Stop a performance timer and log the results
    .PARAMETER Timer
        Timer object from Start-UPMTimer
    .PARAMETER Component
        Component name for logging
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Timer,
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "TIMER"
    )
    
    $Timer.Stopwatch.Stop()
    $duration = $Timer.Stopwatch.Elapsed
    
    $perfData = @{
        Operation = $Timer.Name
        DurationMs = $duration.TotalMilliseconds
        DurationSeconds = $duration.TotalSeconds
        StartTime = $Timer.StartTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        EndTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    }
    
    Write-UPMLog -Message "Operation '$($Timer.Name)' completed in $([math]::Round($duration.TotalSeconds, 2))s" -Level "Debug" -Component $Component -Data $perfData
    
    return $duration
}

function Remove-OldLogFiles {
    <#
    .SYNOPSIS
        Clean up old log files based on retention policy
    .PARAMETER RetentionDays
        Number of days to keep log files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 30
    )
    
    if (-not $script:LogDirectory -or -not (Test-Path $script:LogDirectory)) {
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $logFiles = Get-ChildItem -Path $script:LogDirectory -Filter "UPM-*.log" -File
    $removedCount = 0
    
    foreach ($logFile in $logFiles) {
        if ($logFile.CreationTime -lt $cutoffDate) {
            try {
                Remove-Item -Path $logFile.FullName -Force
                $removedCount++
            }
            catch {
                Write-UPMLog -Message "Failed to remove old log file: $($logFile.Name) - $($_.Exception.Message)" -Level "Warning" -Component "CLEANUP"
            }
        }
    }
    
    if ($removedCount -gt 0) {
        Write-UPMLog -Message "Cleaned up $removedCount old log files (older than $RetentionDays days)" -Level "Info" -Component "CLEANUP"
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-UPMLogging',
    'Write-UPMLog',
    'Start-UPMTimer',
    'Stop-UPMTimer',
    'Remove-OldLogFiles'
)