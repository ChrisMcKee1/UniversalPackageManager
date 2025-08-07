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
$script:EnableEventLog = $true
$script:EnableFileLog = $true
$script:EnableConsoleLogs = $true
$script:EventSource = "UniversalPackageManager"
$script:SessionId = [guid]::NewGuid().ToString("N")[0..7] -join ""
$script:CurrentLogFile = $null

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
        Initialize the logging system with Windows Event Log and file logging
    .PARAMETER LogDirectory
        Directory path for log files
    .PARAMETER LogLevel
        Minimum log level to output
    .PARAMETER EnableEventLog
        Enable Windows Event Log logging
    .PARAMETER EnableFileLog
        Enable file logging
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
        [bool]$EnableEventLog = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableFileLog = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableConsoleLogs = $true
    )
    
    $script:LogDirectory = $LogDirectory
    $script:LogLevel = $LogLevel
    $script:EnableEventLog = $EnableEventLog
    $script:EnableFileLog = $EnableFileLog
    $script:EnableConsoleLogs = $EnableConsoleLogs
    
    # Initialize Windows Event Log source
    if ($EnableEventLog) {
        Initialize-EventLogSource
    }
    
    # Ensure log directory exists and set up daily log file
    if ($EnableFileLog) {
        if (-not (Test-Path -Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }
        
        $dateString = Get-Date -Format "yyyyMMdd"
        $script:CurrentLogFile = Join-Path $LogDirectory "UPM-$dateString.log"
    }
    
    Write-UPMLog -Message "Logging system initialized (EventLog: $EnableEventLog, FileLog: $EnableFileLog)" -Level "Info" -Component "LOGGING"
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
        SessionId = $script:SessionId
        Data = $Data
    }
    
    # Write to Windows Event Log
    if ($script:EnableEventLog) {
        Write-EventLogEntry -LogEntry $logEntry
    }
    
    # Write to file log
    if ($script:EnableFileLog -and $script:CurrentLogFile) {
        Write-FileLogEntry -LogEntry $logEntry
    }
    
    # Write to console with colors
    if ($script:EnableConsoleLogs) {
        Write-ConsoleLog -LogEntry $logEntry
    }
}

function Initialize-EventLogSource {
    <#
    .SYNOPSIS
        Initialize Windows Event Log source for UPM
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if running as administrator (required for event source creation)
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin -and -not [System.Diagnostics.EventLog]::SourceExists($script:EventSource)) {
            [System.Diagnostics.EventLog]::CreateEventSource($script:EventSource, "Application")
        }
    }
    catch {
        # Silently fail if we can't create the event source
        $script:EnableEventLog = $false
    }
}

function Write-EventLogEntry {
    <#
    .SYNOPSIS
        Write log entry to Windows Event Log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry
    )
    
    try {
        $eventType = switch ($LogEntry.Level) {
            "Error"   { "Error" }
            "Warning" { "Warning" }
            "Success" { "Information" }
            "Info"    { "Information" }
            "Debug"   { "Information" }
            default   { "Information" }
        }
        
        $eventId = switch ($LogEntry.Level) {
            "Error"   { 1001 }
            "Warning" { 1002 }
            "Success" { 1003 }
            "Info"    { 1004 }
            "Debug"   { 1005 }
            default   { 1000 }
        }
        
        $message = "[$($LogEntry.Component)] $($LogEntry.Message)"
        if ($LogEntry.Data.Count -gt 0) {
            $dataString = ($LogEntry.Data.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join ", "
            $message += "`nData: $dataString"
        }
        
        Write-EventLog -LogName "Application" -Source $script:EventSource -EventId $eventId -EntryType $eventType -Message $message
    }
    catch {
        # Silently fail if we can't write to event log
    }
}

function Write-FileLogEntry {
    <#
    .SYNOPSIS
        Write log entry to file in standard format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry
    )
    
    try {
        $levelPadded = $LogEntry.Level.PadRight(7)
        $componentPadded = $LogEntry.Component.PadRight(10)
        $logLine = "$($LogEntry.Timestamp) [$levelPadded] [$componentPadded] $($LogEntry.Message)"
        
        # Add data if present and level is Debug
        if ($LogEntry.Data.Count -gt 0 -and $LogEntry.Level -eq "Debug") {
            $dataString = ($LogEntry.Data.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
            $logLine += " | Data: $dataString"
        }
        
        Add-Content -Path $script:CurrentLogFile -Value $logLine -Encoding UTF8
    }
    catch {
        # Silently fail if we can't write to file
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
    # Clean up both old log formats
    $logFiles = Get-ChildItem -Path $script:LogDirectory -Filter "UPM-*.log" -File
    $oldJsonFiles = Get-ChildItem -Path $script:LogDirectory -Filter "UPM-*.json.log" -File
    $allFiles = $logFiles + $oldJsonFiles
    $removedCount = 0
    
    foreach ($logFile in $allFiles) {
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