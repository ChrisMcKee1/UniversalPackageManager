#Requires -Version 7.0

<#
.SYNOPSIS
    Universal Package Manager - Configuration Module
.DESCRIPTION
    Handles loading, validating, and managing UPM configuration from JSON files
    with support for schema validation and default value merging.
.NOTES
    Part of Universal Package Manager v3.0 - PowerShell 7+ Exclusive
#>

using module ./UPM.Logging.psm1

# Global module variables
$script:Config = $null
$script:ConfigPath = $null
$script:DefaultConfig = @{
    "_metadata" = @{
        "version" = "3.0"
        "schema" = "https://github.com/UniversalPackageManager/schema/v3.0"
        "description" = "Universal Package Manager v3.0 - PowerShell 7+ Exclusive"
    }
    "Advanced" = @{
        "maxRetries" = 3
        "parallelUpdates" = $false
        "skipFailedPackages" = $true
        "maxParallel" = 4
        "retryDelay" = 30
        "enableStructuredLogging" = $true
        "enableProgressBars" = $true
        "enablePerformanceMetrics" = $true
        "logRetentionDays" = 30
    }
    "Service" = @{
        "frequency" = "Daily"
        "updateTime" = "02:00"
        "enabled" = $true
        "taskName" = "Universal Package Manager v3.0"
        "runAsSystem" = $true
        "highestPrivileges" = $true
    }
    "Logging" = @{
        "defaultLevel" = "Info"
        "enableJsonLogs" = $true
        "enableConsoleLogs" = $true
        "enableFileRotation" = $true
        "maxLogFiles" = 30
        "logDirectory" = "logs"
    }
    "UI" = @{
        "progressStyle" = "Minimal"
        "enableEmojis" = $false  # Disabled for compatibility
        "enableColors" = $true
        "progressMaxWidth" = 120
    }
    "PackageManagers" = @{
        "winget" = @{
            "enabled" = $true
            "args" = "--accept-source-agreements --accept-package-agreements --silent"
            "timeout" = 600
            "priority" = 1
            "description" = "Microsoft's official package manager"
        }
        "choco" = @{
            "enabled" = $true
            "args" = "-y --limit-output"
            "timeout" = 900
        }
        "scoop" = @{
            "enabled" = $true
            "args" = ""
            "timeout" = 300
        }
        "npm" = @{
            "enabled" = $true
            "args" = ""
            "timeout" = 600
        }
        "pip" = @{
            "enabled" = $true
            "args" = "--quiet"
            "timeout" = 600
        }
        "conda" = @{
            "enabled" = $true
            "args" = "-y --quiet"
            "timeout" = 900
        }
    }
}

function Initialize-UPMConfiguration {
    <#
    .SYNOPSIS
        Initialize configuration system and load settings
    .PARAMETER ConfigPath
        Path to the configuration JSON file
    .PARAMETER CreateIfMissing
        Create default config if file doesn't exist
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateIfMissing
    )
    
    $script:ConfigPath = $ConfigPath
    
    try {
        if (-not (Test-Path -Path $ConfigPath)) {
            if ($CreateIfMissing) {
                Write-UPMLog -Message "Configuration file not found, creating default: $ConfigPath" -Level "Info" -Component "CONFIG"
                New-UPMConfiguration -Path $ConfigPath
            }
            else {
                throw "Configuration file not found: $ConfigPath"
            }
        }
        
        $script:Config = Read-UPMConfiguration -Path $ConfigPath
        Write-UPMLog -Message "Configuration loaded successfully" -Level "Success" -Component "CONFIG"
        
        # Validate configuration
        $validationResult = Test-UPMConfiguration -Config $script:Config
        if (-not $validationResult.IsValid) {
            Write-UPMLog -Message "Configuration validation warnings: $($validationResult.Warnings -join '; ')" -Level "Warning" -Component "CONFIG"
        }
        
        return $script:Config
    }
    catch {
        Write-UPMLog -Message "Failed to initialize configuration: $($_.Exception.Message)" -Level "Error" -Component "CONFIG"
        throw
    }
}

function Read-UPMConfiguration {
    <#
    .SYNOPSIS
        Read and parse configuration from JSON file
    .PARAMETER Path
        Path to configuration JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $configJson = Get-Content -Path $Path -Raw -Encoding UTF8
        $config = $configJson | ConvertFrom-Json -AsHashtable -Depth 10
        
        # Merge with defaults to ensure all required properties exist
        $mergedConfig = Merge-UPMConfiguration -DefaultConfig $script:DefaultConfig -UserConfig $config
        
        Write-UPMLog -Message "Configuration read from: $Path" -Level "Debug" -Component "CONFIG" -Data @{
            "ConfigVersion" = $mergedConfig._metadata.version
            "PackageManagerCount" = $mergedConfig.PackageManagers.Count
            "EnabledManagers" = ($mergedConfig.PackageManagers.GetEnumerator() | Where-Object { $_.Value.enabled } | Measure-Object).Count
        }
        
        return $mergedConfig
    }
    catch {
        Write-UPMLog -Message "Failed to read configuration: $($_.Exception.Message)" -Level "Error" -Component "CONFIG"
        throw
    }
}

function New-UPMConfiguration {
    <#
    .SYNOPSIS
        Create a new configuration file with default settings
    .PARAMETER Path
        Path where to create the configuration file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        # Ensure directory exists
        $configDir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        # Add current timestamp
        $configToWrite = $script:DefaultConfig.Clone()
        $configToWrite._metadata.lastModified = Get-Date -Format "yyyy-MM-dd"
        
        $configJson = $configToWrite | ConvertTo-Json -Depth 10
        $configJson | Set-Content -Path $Path -Encoding UTF8
        
        Write-UPMLog -Message "Default configuration created: $Path" -Level "Success" -Component "CONFIG"
        return $configToWrite
    }
    catch {
        Write-UPMLog -Message "Failed to create configuration: $($_.Exception.Message)" -Level "Error" -Component "CONFIG"
        throw
    }
}

function Merge-UPMConfiguration {
    <#
    .SYNOPSIS
        Merge user configuration with defaults
    .PARAMETER DefaultConfig
        Default configuration hashtable
    .PARAMETER UserConfig
        User configuration hashtable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DefaultConfig,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$UserConfig
    )
    
    $mergedConfig = $DefaultConfig.Clone()
    
    foreach ($key in $UserConfig.Keys) {
        if ($mergedConfig.ContainsKey($key)) {
            if ($mergedConfig[$key] -is [hashtable] -and $UserConfig[$key] -is [hashtable]) {
                # Recursively merge nested hashtables
                $mergedConfig[$key] = Merge-UPMConfiguration -DefaultConfig $mergedConfig[$key] -UserConfig $UserConfig[$key]
            }
            else {
                # Override with user value
                $mergedConfig[$key] = $UserConfig[$key]
            }
        }
        else {
            # Add new user key
            $mergedConfig[$key] = $UserConfig[$key]
        }
    }
    
    return $mergedConfig
}

function Test-UPMConfiguration {
    <#
    .SYNOPSIS
        Validate configuration for common issues
    .PARAMETER Config
        Configuration hashtable to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $warnings = @()
    $isValid = $true
    
    # Check required sections
    $requiredSections = @("PackageManagers", "Service", "Logging")
    foreach ($section in $requiredSections) {
        if (-not $Config.ContainsKey($section)) {
            $warnings += "Missing required section: $section"
            $isValid = $false
        }
    }
    
    # Validate package managers
    if ($Config.ContainsKey("PackageManagers")) {
        $enabledCount = 0
        foreach ($pm in $Config.PackageManagers.GetEnumerator()) {
            if ($pm.Value.enabled) {
                $enabledCount++
            }
            
            if (-not $pm.Value.ContainsKey("timeout") -or $pm.Value.timeout -le 0) {
                $warnings += "Package manager '$($pm.Key)' has invalid timeout"
            }
        }
        
        if ($enabledCount -eq 0) {
            $warnings += "No package managers are enabled"
        }
    }
    
    # Validate service settings
    if ($Config.ContainsKey("Service")) {
        if ($Config.Service.ContainsKey("updateTime")) {
            if ($Config.Service.updateTime -notmatch '^\d{2}:\d{2}$') {
                $warnings += "Invalid updateTime format (should be HH:MM)"
            }
        }
        
        if ($Config.Service.ContainsKey("frequency")) {
            if ($Config.Service.frequency -notin @("Daily", "Weekly")) {
                $warnings += "Invalid frequency (should be Daily or Weekly)"
            }
        }
    }
    
    return @{
        IsValid = ($warnings.Count -eq 0)
        Warnings = $warnings
    }
}

function Get-UPMConfiguration {
    <#
    .SYNOPSIS
        Get the current loaded configuration
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:Config) {
        throw "Configuration not initialized. Call Initialize-UPMConfiguration first."
    }
    
    return $script:Config
}

function Get-UPMPackageManagers {
    <#
    .SYNOPSIS
        Get enabled package managers from configuration
    .PARAMETER EnabledOnly
        Return only enabled package managers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$EnabledOnly
    )
    
    $config = Get-UPMConfiguration
    $packageManagers = $config.PackageManagers
    
    if ($EnabledOnly) {
        $enabledManagers = @{}
        foreach ($pm in $packageManagers.GetEnumerator()) {
            if ($pm.Value.enabled) {
                $enabledManagers[$pm.Key] = $pm.Value
            }
        }
        return $enabledManagers
    }
    
    return $packageManagers
}

function Update-UPMConfiguration {
    <#
    .SYNOPSIS
        Update a configuration value and save to file
    .PARAMETER Section
        Configuration section name
    .PARAMETER Key
        Configuration key name
    .PARAMETER Value
        New value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    try {
        $config = Get-UPMConfiguration
        
        if (-not $config.ContainsKey($Section)) {
            $config[$Section] = @{}
        }
        
        $config[$Section][$Key] = $Value
        $config._metadata.lastModified = Get-Date -Format "yyyy-MM-dd"
        
        # Save to file
        $configJson = $config | ConvertTo-Json -Depth 10
        $configJson | Set-Content -Path $script:ConfigPath -Encoding UTF8
        
        Write-UPMLog -Message "Configuration updated: $Section.$Key = $Value" -Level "Info" -Component "CONFIG"
        
        return $config
    }
    catch {
        Write-UPMLog -Message "Failed to update configuration: $($_.Exception.Message)" -Level "Error" -Component "CONFIG"
        throw
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-UPMConfiguration',
    'Read-UPMConfiguration',
    'New-UPMConfiguration',
    'Test-UPMConfiguration',
    'Get-UPMConfiguration',
    'Get-UPMPackageManagers',
    'Update-UPMConfiguration'
)