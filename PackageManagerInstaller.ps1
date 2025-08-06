#Requires -Version 7.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Package Manager Installer for Universal Package Manager v3.0
.DESCRIPTION
    Installs and upgrades package managers supported by Universal Package Manager.
    If package managers are already installed, they will be upgraded to the latest version.
    
    Supported Package Managers:
    - Windows Package Manager (winget) - Usually pre-installed on Windows 11
    - Chocolatey - Community package manager for Windows  
    - Scoop - Command-line installer for Windows
    - Node.js and NPM - JavaScript runtime and package manager
    - Python and pip - Python runtime and package manager
    - Miniconda/conda - Python data science package manager
.PARAMETER PackageManagers
    Array of package managers to install/upgrade. Default: all supported managers
.PARAMETER Force
    Force reinstall even if already installed
.PARAMETER SkipConfirmation
    Skip confirmation prompts for automated execution
.EXAMPLE
    .\PackageManagerInstaller.ps1
    Install all supported package managers
.EXAMPLE
    .\PackageManagerInstaller.ps1 -PackageManagers @("choco", "scoop")
    Install only Chocolatey and Scoop
.EXAMPLE
    .\PackageManagerInstaller.ps1 -Force -SkipConfirmation
    Force reinstall all package managers without prompts
.NOTES
    Version: 1.0
    Requires: Administrator privileges and PowerShell 7.0+
    Part of Universal Package Manager v3.0 ecosystem
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("winget", "choco", "scoop", "nodejs", "python", "conda", "all")]
    [string[]]$PackageManagers = @(),  # Empty array to allow config override
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfirmation,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ""
)

# Modern PowerShell 7+ error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Script variables
$script:BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DefaultConfigPath = Join-Path $script:BaseDir "config\settings.json"

# Logging function with modern PowerShell features
function Write-InstallerLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "INSTALLER"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    $color = switch ($Level) {
        "Info"    { $PSStyle.Foreground.White }
        "Success" { $PSStyle.Foreground.Green }
        "Warning" { $PSStyle.Foreground.Yellow }
        "Error"   { $PSStyle.Foreground.Red }
        "Debug"   { $PSStyle.Foreground.Gray }
    }
    
    $prefix = switch ($Level) {
        "Info"    { "INFO:" }
        "Success" { "SUCCESS:" }
        "Warning" { "WARNING:" }
        "Error"   { "ERROR:" }
        "Debug"   { "DEBUG:" }
    }
    
    Write-Host "$color[$timestamp] [$Component] $prefix $Message$($PSStyle.Reset)"
}

function Get-InstallerConfiguration {
    <#
    .SYNOPSIS
        Load configuration from settings.json
    #>
    [CmdletBinding()]
    param()
    
    try {
        $configPath = if ($ConfigPath) { $ConfigPath } else { $script:DefaultConfigPath }
        
        if (Test-Path $configPath) {
            Write-InstallerLog "Loading configuration from: $configPath" -Level "Debug"
            $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            
            if ($config.ContainsKey("PackageManagerInstaller")) {
                return $config.PackageManagerInstaller
            }
        }
        
        Write-InstallerLog "Using default configuration (no config file found or no PackageManagerInstaller section)" -Level "Debug"
        return @{
            "defaultPackageManagers" = @("all")
            "autoAccept" = $true
            "forceReinstall" = $false
            "preferredInstallMethods" = @{
                "winget" = "store"
                "nodejs" = "winget"
                "python" = "winget" 
                "conda" = "winget"
            }
        }
    }
    catch {
        Write-InstallerLog "Error loading configuration: $($_.Exception.Message)" -Level "Warning"
        return @{
            "defaultPackageManagers" = @("all")
            "autoAccept" = $true
            "forceReinstall" = $false
        }
    }
}

function Test-Administrator {
    <#
    .SYNOPSIS
        Test if running as administrator
    #>
    try {
        $currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
    catch {
        Write-InstallerLog "Failed to check administrator privileges: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}


# Global variable to track PATH backups for rollback
$script:PathBackups = @{}

function Backup-PathEnvironment {
    <#
    .SYNOPSIS
        Create a backup of current PATH environment variables
    .PARAMETER BackupId
        Unique identifier for this backup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupId
    )
    
    try {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
        $machinePath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
        $sessionPath = $env:PATH
        
        $script:PathBackups[$BackupId] = @{
            UserPath = $userPath
            MachinePath = $machinePath
            SessionPath = $sessionPath
            Timestamp = Get-Date
            BackupId = $BackupId
        }
        
        # Also save to file for persistence across sessions
        $backupDir = Join-Path $script:BaseDir "backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }
        
        $backupFile = Join-Path $backupDir "PATH-backup-$BackupId-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $script:PathBackups[$BackupId] | ConvertTo-Json -Depth 3 | Set-Content -Path $backupFile -Encoding UTF8
        
        Write-InstallerLog "PATH backup created: $BackupId" -Level "Success" -Component "PATH"
        Write-InstallerLog "Backup file: $backupFile" -Level "Debug" -Component "PATH"
        
        return $true
    }
    catch {
        Write-InstallerLog "Failed to backup PATH: $($_.Exception.Message)" -Level "Error" -Component "PATH"
        return $false
    }
}

function Restore-PathEnvironment {
    <#
    .SYNOPSIS
        Restore PATH environment variables from backup
    .PARAMETER BackupId
        Backup identifier to restore
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupId
    )
    
    try {
        if (-not $script:PathBackups.ContainsKey($BackupId)) {
            Write-InstallerLog "Backup not found: $BackupId" -Level "Error" -Component "PATH"
            return $false
        }
        
        $backup = $script:PathBackups[$BackupId]
        
        Write-InstallerLog "Restoring PATH from backup: $BackupId" -Level "Warning" -Component "PATH"
        
        # Restore user PATH
        [Environment]::SetEnvironmentVariable("PATH", $backup.UserPath, [EnvironmentVariableTarget]::User)
        
        # Restore session PATH
        $env:PATH = $backup.SessionPath
        
        Write-InstallerLog "PATH successfully restored from backup" -Level "Success" -Component "PATH"
        return $true
    }
    catch {
        Write-InstallerLog "Failed to restore PATH: $($_.Exception.Message)" -Level "Error" -Component "PATH"
        return $false
    }
}

function Test-PathIntegrity {
    <#
    .SYNOPSIS
        Validate PATH integrity and check for common issues
    .PARAMETER PathValue
        PATH string to validate
    .PARAMETER Target
        Target scope (User or Machine) - affects validation rules
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("User", "Machine")]
        [string]$Target = "User"
    )
    
    try {
        $pathElements = $PathValue -split ';' | Where-Object { $_.Trim() -ne '' }
        
        # Only validate critical paths for Machine PATH (not User PATH)
        if ($Target -eq "Machine") {
            $criticalPaths = @(
                "$env:SystemRoot\system32",
                "$env:SystemRoot",
                "$env:SystemRoot\System32\Wbem"
            )
            
            # Check if critical paths are present (case-insensitive)
            foreach ($criticalPath in $criticalPaths) {
                $found = $false
                foreach ($element in $pathElements) {
                    if ($element.Trim() -ieq $criticalPath) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    Write-InstallerLog "Critical system path missing from Machine PATH: $criticalPath" -Level "Error" -Component "PATH"
                    Write-InstallerLog "Available paths: $($pathElements -join '; ')" -Level "Debug" -Component "PATH"
                    return $false
                }
            }
        }
        
        # Check for suspicious characteristics
        if ($PathValue.Length -gt 8191) {  # Windows PATH limit
            Write-InstallerLog "PATH exceeds Windows maximum length (8191 characters)" -Level "Error" -Component "PATH"
            return $false
        }
        
        # Check for malformed entries
        $suspiciousPatterns = @(';;', ';;;', '\.\.')
        foreach ($pattern in $suspiciousPatterns) {
            if ($PathValue -like "*$pattern*") {
                Write-InstallerLog "Suspicious PATH pattern detected: $pattern" -Level "Warning" -Component "PATH"
            }
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "PATH integrity check failed: $($_.Exception.Message)" -Level "Error" -Component "PATH"
        return $false
    }
}

function Add-SafePathEntry {
    <#
    .SYNOPSIS
        Safely add a directory to PATH with validation and rollback capability
    .PARAMETER Directory
        Directory to add to PATH
    .PARAMETER Target
        Target scope (User or Machine)
    .PARAMETER BackupId
        Backup ID for rollback capability
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("User", "Machine")]
        [string]$Target = "User",
        
        [Parameter(Mandatory = $true)]
        [string]$BackupId
    )
    
    try {
        # Validate directory exists
        if (-not (Test-Path $Directory -PathType Container)) {
            Write-InstallerLog "Directory does not exist: $Directory" -Level "Error" -Component "PATH"
            return $false
        }
        
        # Get current PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::$Target)
        
        # Check if already in PATH (case-insensitive)
        $pathElements = $currentPath -split ';' | Where-Object { $_.Trim() -ne '' }
        foreach ($element in $pathElements) {
            if ($element.Trim() -ieq $Directory.Trim()) {
                Write-InstallerLog "Directory already in PATH: $Directory" -Level "Debug" -Component "PATH"
                return $true
            }
        }
        
        # Create new PATH
        $newPath = if ($currentPath -and -not $currentPath.EndsWith(';')) {
            "$currentPath;$Directory"
        } else {
            "$currentPath$Directory"
        }
        
        # Validate new PATH integrity
        if (-not (Test-PathIntegrity -PathValue $newPath -Target $Target)) {
            Write-InstallerLog "New PATH failed integrity check" -Level "Error" -Component "PATH"
            return $false
        }
        
        # Apply change
        Write-InstallerLog "Adding to $Target PATH: $Directory" -Level "Info" -Component "PATH"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::$Target)
        
        # Update session PATH if User target
        if ($Target -eq "User") {
            $env:PATH = "$Directory;" + $env:PATH
        }
        
        # Verify the change was applied
        $verifyPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::$Target)
        if ($verifyPath -like "*$Directory*") {
            Write-InstallerLog "Successfully added to PATH: $Directory" -Level "Success" -Component "PATH"
            return $true
        } else {
            Write-InstallerLog "PATH modification verification failed" -Level "Error" -Component "PATH"
            
            # Attempt rollback
            Write-InstallerLog "Attempting automatic rollback" -Level "Warning" -Component "PATH"
            Restore-PathEnvironment -BackupId $BackupId
            return $false
        }
    }
    catch {
        Write-InstallerLog "Error adding to PATH: $($_.Exception.Message)" -Level "Error" -Component "PATH"
        
        # Attempt rollback on error
        Write-InstallerLog "Attempting automatic rollback due to error" -Level "Warning" -Component "PATH"
        Restore-PathEnvironment -BackupId $BackupId
        return $false
    }
}

function Find-PackageManagerInstallation {
    <#
    .SYNOPSIS
        Find package manager installation directory and add to PATH if needed
    .PARAMETER Name
        Package manager name
    .PARAMETER Command
        Command executable name
    .PARAMETER SearchPaths
        Array of possible installation paths to search
    .PARAMETER BackupId
        Backup ID for PATH operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $true)]
        [string[]]$SearchPaths,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupId
    )
    
    Write-InstallerLog "Searching for $Name installation" -Level "Debug" -Component $Name.ToUpper()
    
    foreach ($basePath in $SearchPaths) {
        try {
            $expandedPath = [Environment]::ExpandEnvironmentVariables($basePath)
            
            # Validate base path exists
            if (-not (Test-Path $expandedPath -PathType Container)) {
                continue
            }
            
            # Check various common subdirectories for the executable
            $possibleExePaths = @(
                "$expandedPath\$Command.exe",
                "$expandedPath\Scripts\$Command.exe", 
                "$expandedPath\bin\$Command.exe",
                "$expandedPath\cmd\$Command.exe"
            )
            
            foreach ($exePath in $possibleExePaths) {
                if (Test-Path $exePath -PathType Leaf) {
                    $installDir = Split-Path $exePath -Parent
                    Write-InstallerLog "Found $Name at: $exePath" -Level "Success" -Component $Name.ToUpper()
                    
                    # Use safe PATH addition
                    $pathAdded = Add-SafePathEntry -Directory $installDir -Target "User" -BackupId $BackupId
                    
                    if (-not $pathAdded) {
                        Write-InstallerLog "Failed to safely add $Name to PATH" -Level "Error" -Component $Name.ToUpper()
                        return @{
                            Found = $true
                            Path = $exePath
                            Directory = $installDir
                            PathAdded = $false
                        }
                    }
                    
                    return @{
                        Found = $true
                        Path = $exePath
                        Directory = $installDir
                        PathAdded = $true
                    }
                }
            }
        }
        catch {
            Write-InstallerLog "Error searching path $basePath`: $($_.Exception.Message)" -Level "Warning" -Component $Name.ToUpper()
            continue
        }
    }
    
    return @{
        Found = $false
        Path = $null
        Directory = $null
        PathAdded = $false
    }
}

function Test-PackageManagerInstalled {
    <#
    .SYNOPSIS
        Test if a package manager is installed and functional
    .PARAMETER Name
        Package manager name
    .PARAMETER Command
        Command to test
    .PARAMETER TestArguments
        Arguments for test command
    .PARAMETER SearchPaths
        Optional array of paths to search if command not found in PATH
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $false)]
        [string]$TestArguments = "--version",
        
        [Parameter(Mandatory = $false)]
        [string[]]$SearchPaths = @()
    )
    
    try {
        Write-InstallerLog "Testing $Name availability" -Level "Debug"
        
        # First check if command exists in PATH
        $commandInfo = Get-Command $Command -ErrorAction SilentlyContinue
        if (-not $commandInfo -and $SearchPaths.Count -gt 0) {
            # Try to find the installation
            Write-InstallerLog "$Command not found in PATH, searching installation directories" -Level "Debug" -Component $Name.ToUpper()
            
            # Create backup ID for this search operation
            $backupId = "search-$Name-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            if (-not (Backup-PathEnvironment -BackupId $backupId)) {
                Write-InstallerLog "Failed to create PATH backup before searching for $Name" -Level "Error" -Component $Name.ToUpper()
                return @{
                    Installed = $false
                    Version = $null
                    Path = $null
                    Error = "PATH backup failed"
                }
            }
            
            $findResult = Find-PackageManagerInstallation -Name $Name -Command $Command -SearchPaths $SearchPaths -BackupId $backupId
            
            if ($findResult.Found) {
                # Try Get-Command again after PATH update
                $commandInfo = Get-Command $Command -ErrorAction SilentlyContinue
            }
        }
        
        if (-not $commandInfo) {
            return @{
                Installed = $false
                Version = $null
                Path = $null
                Error = "Command not found in PATH"
            }
        }
        
        # Test command execution using simple approach without redirection
        try {
            # Use a job to implement timeout functionality
            $job = Start-Job -ScriptBlock {
                param($cmd, $args)
                try {
                    $output = & $cmd $args 2>&1
                    return @{
                        Success = $LASTEXITCODE -eq 0
                        Output = $output -join "`n"
                        ExitCode = $LASTEXITCODE
                    }
                }
                catch {
                    return @{
                        Success = $false
                        Output = $_.Exception.Message
                        ExitCode = -1
                    }
                }
            } -ArgumentList $Command, $TestArguments.Split(' ')
            
            # Wait for job with timeout
            $result = $job | Wait-Job -Timeout 30
            if ($result) {
                $jobResult = Receive-Job -Job $job
                Remove-Job -Job $job -Force
                
                $success = $jobResult.Success
                $output = $jobResult.Output
            } else {
                # Job timed out
                Stop-Job -Job $job
                Remove-Job -Job $job -Force
                $success = $false
                $output = "Command timed out"
            }
        }
        catch {
            $success = $false
            $output = $_.Exception.Message
        }
        
        return @{
            Installed = $success
            Version = if ($success) { $output.Trim() } else { $null }
            Path = $commandInfo.Source
            Error = if (-not $success) { "Command test failed: $output" } else { $null }
        }
    }
    catch {
        Write-InstallerLog "Error testing $Name`: $($_.Exception.Message)" -Level "Debug"
        return @{
            Installed = $false
            Version = $null
            Path = $null
            Error = $_.Exception.Message
        }
    }
}

function Install-Winget {
    <#
    .SYNOPSIS
        Install or upgrade Windows Package Manager (winget)
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-InstallerLog "Processing Windows Package Manager (winget)" -Level "Info" -Component "WINGET"
        
        $wingetInfo = Test-PackageManagerInstalled -Name "winget" -Command "winget"
        
        if ($wingetInfo.Installed -and -not $Force) {
            Write-InstallerLog "Winget is already installed and functional" -Level "Success" -Component "WINGET"
            # Clean up version display for winget
            $cleanVersion = if ($wingetInfo.Version -match "Windows Package Manager\s+(v[\d.]+)") { 
                $matches[1] 
            } elseif ($wingetInfo.Version -match "v[\d.]+") {
                ($wingetInfo.Version -split "`n")[0].Trim()
            } else { 
                ($wingetInfo.Version -split "`n")[0].Trim() 
            }
            Write-InstallerLog "Version: $cleanVersion" -Level "Info" -Component "WINGET"
            return $true
        }
        
        if (-not $wingetInfo.Installed) {
            Write-InstallerLog "Winget not found - attempting to install" -Level "Info" -Component "WINGET"
            
            # Try multiple approaches to install winget
            try {
                # Method 1: Try to register existing App Installer
                Write-InstallerLog "Attempting App Installer registration" -Level "Debug" -Component "WINGET"
                Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
                
                # Wait and test
                Start-Sleep -Seconds 5
                $wingetInfo = Test-PackageManagerInstalled -Name "winget" -Command "winget"
                
                if (-not $wingetInfo.Installed) {
                    # Method 2: Try via Microsoft Store URL
                    Write-InstallerLog "Registration failed, trying Microsoft Store installation" -Level "Info" -Component "WINGET"
                    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction SilentlyContinue
                    
                    Write-InstallerLog "Please install 'App Installer' from Microsoft Store and run this script again" -Level "Warning" -Component "WINGET"
                    return $false
                }
                
                Write-InstallerLog "Winget registered successfully" -Level "Success" -Component "WINGET"
            }
            catch {
                Write-InstallerLog "Auto-installation failed: $($_.Exception.Message)" -Level "Warning" -Component "WINGET"
                Write-InstallerLog "Please install 'App Installer' from Microsoft Store manually" -Level "Info" -Component "WINGET"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "Error installing winget: $($_.Exception.Message)" -Level "Error" -Component "WINGET"
        return $false
    }
}

function Install-Chocolatey {
    <#
    .SYNOPSIS
        Install or upgrade Chocolatey package manager
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-InstallerLog "Processing Chocolatey package manager" -Level "Info" -Component "CHOCO"
        
        $chocoSearchPaths = @(
            "%PROGRAMDATA%\chocolatey\bin",
            "%ALLUSERSPROFILE%\chocolatey\bin", 
            "C:\chocolatey\bin"
        )
        
        $chocoInfo = Test-PackageManagerInstalled -Name "chocolatey" -Command "choco" -SearchPaths $chocoSearchPaths
        
        if ($chocoInfo.Installed) {
            if ($Force) {
                Write-InstallerLog "Upgrading Chocolatey (force mode)" -Level "Info" -Component "CHOCO"
                try {
                    & choco upgrade chocolatey -y --limit-output
                    Write-InstallerLog "Chocolatey upgraded successfully" -Level "Success" -Component "CHOCO"
                }
                catch {
                    Write-InstallerLog "Failed to upgrade Chocolatey: $($_.Exception.Message)" -Level "Warning" -Component "CHOCO"
                }
            } else {
                Write-InstallerLog "Chocolatey is already installed and functional" -Level "Success" -Component "CHOCO"
                # Extract just the version number from output
                $versionOnly = $chocoInfo.Version -split '\n' | Select-Object -First 1
                Write-InstallerLog "Version: $versionOnly" -Level "Info" -Component "CHOCO"
                return $true
            }
        } else {
            # Double-check if choco command exists even if initial test failed
            $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
            if ($chocoPath) {
                Write-InstallerLog "Found existing Chocolatey installation, performing upgrade instead" -Level "Info" -Component "CHOCO"
                try {
                    & choco upgrade chocolatey -y --limit-output
                    if ($LASTEXITCODE -eq 0) {
                        Write-InstallerLog "Chocolatey upgraded successfully" -Level "Success" -Component "CHOCO"
                        return $true
                    }
                }
                catch {
                    Write-InstallerLog "Upgrade failed, will attempt fresh installation" -Level "Warning" -Component "CHOCO"
                }
            }
            
            Write-InstallerLog "Installing Chocolatey from official script" -Level "Info" -Component "CHOCO"
            
            try {
                # Use official Chocolatey installation script
                $originalExecutionPolicy = Get-ExecutionPolicy -Scope Process
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                
                $installScript = Invoke-RestMethod https://community.chocolatey.org/install.ps1 -TimeoutSec 60
                Invoke-Expression $installScript
                
                # Restore execution policy
                Set-ExecutionPolicy $originalExecutionPolicy -Scope Process -Force
                
                # Refresh environment variables
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                
                # Wait a moment for installation to settle
                Start-Sleep -Seconds 3
                
                # Verify installation
                $chocoInfo = Test-PackageManagerInstalled -Name "chocolatey" -Command "choco" -SearchPaths $chocoSearchPaths
                if ($chocoInfo.Installed) {
                    Write-InstallerLog "Chocolatey installed successfully" -Level "Success" -Component "CHOCO"
                } else {
                    throw "Chocolatey installation verification failed"
                }
            }
            catch {
                Write-InstallerLog "Chocolatey installation failed: $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "Error installing Chocolatey: $($_.Exception.Message)" -Level "Error" -Component "CHOCO"
        return $false
    }
}

function Install-Scoop {
    <#
    .SYNOPSIS
        Install or upgrade Scoop package manager
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-InstallerLog "Processing Scoop package manager" -Level "Info" -Component "SCOOP"
        
        $scoopSearchPaths = @(
            "%USERPROFILE%\scoop\shims",
            "%SCOOP%\shims",
            "$env:USERPROFILE\scoop\shims"
        )
        
        $scoopInfo = Test-PackageManagerInstalled -Name "scoop" -Command "scoop" -SearchPaths $scoopSearchPaths
        
        if ($scoopInfo.Installed) {
            if ($Force) {
                Write-InstallerLog "Updating Scoop (force mode)" -Level "Info" -Component "SCOOP"
                & scoop update scoop
            } else {
                Write-InstallerLog "Scoop is already installed and functional" -Level "Success" -Component "SCOOP"
                return $true
            }
        } else {
            Write-InstallerLog "Installing Scoop from official script" -Level "Info" -Component "SCOOP"
            
            try {
                # Check and set execution policy for Scoop
                $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
                if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
                    Write-InstallerLog "Setting execution policy for Scoop installation" -Level "Info" -Component "SCOOP"
                    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                }
                
                # Use official Scoop installation script
                $installScript = Invoke-RestMethod -Uri https://get.scoop.sh -TimeoutSec 60
                Invoke-Expression $installScript
                
                # Wait for installation to complete
                Start-Sleep -Seconds 3
                
                # Refresh PATH for current session
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                
                # Verify installation
                $scoopInfo = Test-PackageManagerInstalled -Name "scoop" -Command "scoop" -SearchPaths $scoopSearchPaths
                if ($scoopInfo.Installed) {
                    Write-InstallerLog "Scoop installed successfully" -Level "Success" -Component "SCOOP"
                } else {
                    throw "Scoop installation verification failed"
                }
            }
            catch {
                Write-InstallerLog "Scoop installation failed: $($_.Exception.Message)" -Level "Error" -Component "SCOOP"
                Write-InstallerLog "You may need to manually install Scoop from https://scoop.sh/" -Level "Info" -Component "SCOOP"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "Error installing Scoop: $($_.Exception.Message)" -Level "Error" -Component "SCOOP"
        return $false
    }
}

function Install-NodeJS {
    <#
    .SYNOPSIS
        Install or upgrade Node.js and NPM
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-InstallerLog "Processing Node.js and NPM" -Level "Info" -Component "NODEJS"
        
        $nodeSearchPaths = @(
            "%PROGRAMFILES%\nodejs",
            "%PROGRAMFILES(X86)%\nodejs", 
            "%APPDATA%\npm",
            "%USERPROFILE%\AppData\Local\Programs\Node"
        )
        
        $nodeInfo = Test-PackageManagerInstalled -Name "node" -Command "node" -SearchPaths $nodeSearchPaths
        $npmInfo = Test-PackageManagerInstalled -Name "npm" -Command "npm" -SearchPaths $nodeSearchPaths
        
        if ($nodeInfo.Installed -and $npmInfo.Installed -and -not $Force) {
            Write-InstallerLog "Node.js and NPM are already installed" -Level "Success" -Component "NODEJS"
            Write-InstallerLog "Node version: $($nodeInfo.Version)" -Level "Info" -Component "NODEJS"
            Write-InstallerLog "NPM version: $($npmInfo.Version)" -Level "Info" -Component "NODEJS"
            return $true
        }
        
        Write-InstallerLog "Installing Node.js LTS via winget" -Level "Info" -Component "NODEJS"
        
        # Try to install via winget first
        $wingetAvailable = Test-PackageManagerInstalled -Name "winget" -Command "winget"
        if ($wingetAvailable.Installed) {
            & winget install OpenJS.NodeJS --accept-source-agreements --accept-package-agreements --silent
        } else {
            # Fallback: provide instructions for manual installation
            Write-InstallerLog "Winget not available - please install Node.js manually from https://nodejs.org/" -Level "Warning" -Component "NODEJS"
            return $false
        }
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Verify installation
        Start-Sleep -Seconds 5
        $nodeInfo = Test-PackageManagerInstalled -Name "node" -Command "node" -SearchPaths $nodeSearchPaths
        $npmInfo = Test-PackageManagerInstalled -Name "npm" -Command "npm" -SearchPaths $nodeSearchPaths
        
        if ($nodeInfo.Installed -and $npmInfo.Installed) {
            Write-InstallerLog "Node.js and NPM installed successfully" -Level "Success" -Component "NODEJS"
        } else {
            Write-InstallerLog "Node.js installation may require a system restart to update PATH" -Level "Warning" -Component "NODEJS"
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "Error installing Node.js: $($_.Exception.Message)" -Level "Error" -Component "NODEJS"
        return $false
    }
}

function Install-Python {
    <#
    .SYNOPSIS
        Install or upgrade Python and pip
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-InstallerLog "Processing Python and pip" -Level "Info" -Component "PYTHON"
        
        $pythonSearchPaths = @(
            "%USERPROFILE%\AppData\Local\Programs\Python\Python312",
            "%USERPROFILE%\AppData\Local\Programs\Python\Python311", 
            "%USERPROFILE%\AppData\Local\Programs\Python\Python310",
            "%PROGRAMFILES%\Python312",
            "%PROGRAMFILES%\Python311",
            "%PROGRAMFILES%\Python310",
            "%PROGRAMFILES(X86)%\Python312",
            "%PROGRAMFILES(X86)%\Python311",
            "%PROGRAMFILES(X86)%\Python310"
        )
        
        $pythonInfo = Test-PackageManagerInstalled -Name "python" -Command "python" -SearchPaths $pythonSearchPaths
        $pipInfo = Test-PackageManagerInstalled -Name "pip" -Command "pip" -SearchPaths $pythonSearchPaths
        
        if ($pythonInfo.Installed -and $pipInfo.Installed -and -not $Force) {
            Write-InstallerLog "Python and pip are already installed" -Level "Success" -Component "PYTHON"
            Write-InstallerLog "Python version: $($pythonInfo.Version)" -Level "Info" -Component "PYTHON"
            # Clean up pip version display 
            $cleanPipVersion = if ($pipInfo.Version -match "^pip\s+[\d.]+") {
                $matches[0]
            } else {
                ($pipInfo.Version -split "`n")[0].Trim()
            }
            Write-InstallerLog "pip version: $cleanPipVersion" -Level "Info" -Component "PYTHON"
            
            # Upgrade pip if already installed
            Write-InstallerLog "Upgrading pip to latest version" -Level "Info" -Component "PYTHON"
            & python -m pip install --upgrade pip --quiet
            
            return $true
        }
        
        Write-InstallerLog "Installing Python via winget" -Level "Info" -Component "PYTHON"
        
        # Try to install via winget first
        $wingetAvailable = Test-PackageManagerInstalled -Name "winget" -Command "winget"
        if ($wingetAvailable.Installed) {
            & winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements --silent
        } else {
            Write-InstallerLog "Winget not available - please install Python manually from https://python.org/" -Level "Warning" -Component "PYTHON"
            return $false
        }
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Verify installation
        Start-Sleep -Seconds 5
        $pythonInfo = Test-PackageManagerInstalled -Name "python" -Command "python" -SearchPaths $pythonSearchPaths
        $pipInfo = Test-PackageManagerInstalled -Name "pip" -Command "pip" -SearchPaths $pythonSearchPaths
        
        if ($pythonInfo.Installed -and $pipInfo.Installed) {
            Write-InstallerLog "Python and pip installed successfully" -Level "Success" -Component "PYTHON"
            
            # Upgrade pip
            try {
                & python -m pip install --upgrade pip --quiet
                if ($LASTEXITCODE -eq 0) {
                    Write-InstallerLog "pip upgraded successfully" -Level "Success" -Component "PYTHON"
                }
            }
            catch {
                Write-InstallerLog "Failed to upgrade pip: $($_.Exception.Message)" -Level "Warning" -Component "PYTHON"
            }
        } else {
            Write-InstallerLog "Python installation may require a system restart to update PATH" -Level "Warning" -Component "PYTHON"
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "Error installing Python: $($_.Exception.Message)" -Level "Error" -Component "PYTHON"
        return $false
    }
}

function Install-Conda {
    <#
    .SYNOPSIS
        Install or upgrade Miniconda (conda)
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-InstallerLog "Processing Miniconda (conda)" -Level "Info" -Component "CONDA"
        
        $condaSearchPaths = @(
            "%USERPROFILE%\AppData\Local\miniconda3",
            "%LOCALAPPDATA%\miniconda3",
            "C:\miniconda3",
            "%PROGRAMFILES%\Miniconda3",
            "%PROGRAMFILES(X86)%\Miniconda3"
        )
        
        $condaInfo = Test-PackageManagerInstalled -Name "conda" -Command "conda" -SearchPaths $condaSearchPaths
        
        if ($condaInfo.Installed) {
            if ($Force) {
                Write-InstallerLog "Updating conda (force mode)" -Level "Info" -Component "CONDA"
                & conda update conda -y --quiet
            } else {
                Write-InstallerLog "Conda is already installed and functional" -Level "Success" -Component "CONDA"
                
                # Extract clean version info
                $condaVersionClean = ($condaInfo.Version -split '\n' | Select-Object -First 1).Trim()
                Write-InstallerLog "Version: $condaVersionClean" -Level "Info" -Component "CONDA"
                
                # Still ensure TOS is accepted for existing installations
                Write-InstallerLog "Ensuring conda non-interactive configuration" -Level "Debug" -Component "CONDA"
                try {
                    # Accept Terms of Service and configure non-interactive mode
                    & conda config --set always_yes true --quiet 2>$null
                    $tosChannels = @(
                        "https://repo.anaconda.com/pkgs/main",
                        "https://repo.anaconda.com/pkgs/r", 
                        "https://repo.anaconda.com/pkgs/msys2"
                    )
                    foreach ($channel in $tosChannels) {
                        & conda tos accept --override-channels --channel $channel --quiet 2>$null
                    }
                } catch {
                    # Ignore TOS configuration errors
                }
                
                return $true
            }
        } else {
            Write-InstallerLog "Installing Miniconda via winget" -Level "Info" -Component "CONDA"
            
            # Try to install via winget first
            $wingetAvailable = Test-PackageManagerInstalled -Name "winget" -Command "winget"
            if ($wingetAvailable.Installed) {
                & winget install Anaconda.Miniconda3 --accept-source-agreements --accept-package-agreements --silent
            } else {
                Write-InstallerLog "Winget not available - please install Miniconda manually from https://conda.io/miniconda.html" -Level "Warning" -Component "CONDA"
                return $false
            }
            
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            
            # Wait for winget installation to complete
            Start-Sleep -Seconds 10
            
            # Verify installation (includes automatic PATH detection and configuration)
            $condaInfo = Test-PackageManagerInstalled -Name "conda" -Command "conda" -SearchPaths $condaSearchPaths
            
            if ($condaInfo.Installed) {
                Write-InstallerLog "Miniconda installed successfully" -Level "Success" -Component "CONDA"
                
                # Initialize conda for PowerShell and accept Terms of Service
                try {
                    Write-InstallerLog "Configuring conda for non-interactive use" -Level "Info" -Component "CONDA"
                    
                    # Accept Terms of Service for common channels
                    $tosChannels = @(
                        "https://repo.anaconda.com/pkgs/main",
                        "https://repo.anaconda.com/pkgs/r", 
                        "https://repo.anaconda.com/pkgs/msys2"
                    )
                    
                    foreach ($channel in $tosChannels) {
                        Write-InstallerLog "Accepting Terms of Service for conda channel" -Level "Debug" -Component "CONDA"
                        try {
                            & conda tos accept --override-channels --channel $channel --quiet 2>$null
                        } catch {
                            # Ignore TOS errors - might already be accepted
                        }
                    }
                    
                    # Configure conda for non-interactive operation
                    & conda config --set always_yes true --quiet 2>$null
                    
                    Write-InstallerLog "Initializing conda for PowerShell" -Level "Info" -Component "CONDA"
                    & conda init powershell --quiet
                    Write-InstallerLog "Conda initialization completed" -Level "Success" -Component "CONDA"
                }
                catch {
                    Write-InstallerLog "Conda initialization failed: $($_.Exception.Message)" -Level "Warning" -Component "CONDA"
                }
            } else {
                Write-InstallerLog "Miniconda installation verification failed" -Level "Error" -Component "CONDA"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-InstallerLog "Error installing Miniconda: $($_.Exception.Message)" -Level "Error" -Component "CONDA"
        return $false
    }
}

# Main execution
function Invoke-PackageManagerInstallation {
    <#
    .SYNOPSIS
        Main installation orchestrator
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "$($PSStyle.Foreground.Cyan)Universal Package Manager - Package Manager Installer v1.0$($PSStyle.Reset)"
        Write-Host "$($PSStyle.Foreground.Cyan)============================================================$($PSStyle.Reset)"
        Write-Host ""
        
        # Verify administrator privileges
        if (-not (Test-Administrator)) {
            throw "This script must be run as Administrator. Please right-click and 'Run as Administrator'"
        }
        
        Write-InstallerLog "Administrator privileges verified" -Level "Success"
        Write-InstallerLog "PowerShell version: $($PSVersionTable.PSVersion)" -Level "Info"
        
        # Create initial PATH backup before any operations
        $masterBackupId = "master-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (-not (Backup-PathEnvironment -BackupId $masterBackupId)) {
            throw "Failed to create master PATH backup. Installation aborted for safety."
        }
        Write-InstallerLog "Master PATH backup created: $masterBackupId" -Level "Success"
        
        # Load configuration
        $installerConfig = Get-InstallerConfiguration
        
        # Determine which package managers to install
        # Priority: Command line params > Config file > Default
        if ($PackageManagers.Count -eq 0) {
            # No command line params provided, use config
            $PackageManagers = $installerConfig.defaultPackageManagers
            Write-InstallerLog "Using package managers from configuration: $($PackageManagers -join ', ')" -Level "Info"
        }
        
        $managersToInstall = if ($PackageManagers -contains "all") {
            @("winget", "choco", "scoop", "nodejs", "python", "conda")
        } else {
            $PackageManagers
        }
        
        # Apply config-based settings if not overridden by command line
        if (-not $Force -and $installerConfig.forceReinstall) {
            $Force = $true
            Write-InstallerLog "Force reinstall enabled from configuration" -Level "Info"
        }
        
        if (-not $SkipConfirmation -and $installerConfig.autoAccept) {
            $SkipConfirmation = $true
        }
        
        Write-InstallerLog "Package managers to process: $($managersToInstall -join ', ')" -Level "Info"
        
        if (-not $SkipConfirmation) {
            Write-Host "This will install/upgrade the following package managers:" -ForegroundColor Yellow
            $managersToInstall | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            Write-Host ""
            
            $confirmation = Read-Host "Continue? (y/N)"
            if ($confirmation -notlike "y*") {
                Write-InstallerLog "Installation cancelled by user" -Level "Warning"
                return
            }
        }
        
        $results = @{}
        $successCount = 0
        
        # Install each package manager
        foreach ($manager in $managersToInstall) {
            Write-Host ""
            Write-InstallerLog "Processing $manager..." -Level "Info"
            
            try {
                $success = switch ($manager.ToLower()) {
                    "winget"  { Install-Winget }
                    "choco"   { Install-Chocolatey }
                    "scoop"   { Install-Scoop }
                    "nodejs"  { Install-NodeJS }
                    "python"  { Install-Python }
                    "conda"   { Install-Conda }
                    default   { 
                        Write-InstallerLog "Unknown package manager: $manager" -Level "Error"
                        $false 
                    }
                }
                
                $results[$manager] = $success
                if ($success) { $successCount++ }
            }
            catch {
                Write-InstallerLog "Failed to install $manager`: $($_.Exception.Message)" -Level "Error"
                $results[$manager] = $false
            }
        }
        
        # Summary
        Write-Host ""
        Write-Host "$($PSStyle.Foreground.Cyan)Installation Summary$($PSStyle.Reset)"
        Write-Host "$($PSStyle.Foreground.Cyan)====================$($PSStyle.Reset)"
        
        foreach ($result in $results.GetEnumerator()) {
            $status = if ($result.Value) { 
                "$($PSStyle.Foreground.Green)SUCCESS$($PSStyle.Reset)" 
            } else { 
                "$($PSStyle.Foreground.Red)FAILED$($PSStyle.Reset)" 
            }
            Write-Host "$($result.Key): $status"
        }
        
        Write-Host ""
        $failureCount = $managersToInstall.Count - $successCount
        
        if ($failureCount -eq 0) {
            Write-InstallerLog "All package managers processed successfully!" -Level "Success"
        } elseif ($successCount -gt 0) {
            Write-InstallerLog "$successCount successful, $failureCount failed" -Level "Warning"
        } else {
            Write-InstallerLog "All installations failed" -Level "Error"
        }
        
        Write-Host ""
        Write-InstallerLog "You may need to restart your PowerShell session or computer for PATH changes to take effect" -Level "Info"
        Write-InstallerLog "You can now run Universal Package Manager to use these package managers" -Level "Success"
        
        # Provide recovery information
        Write-Host ""
        Write-InstallerLog "PATH Recovery Information:" -Level "Info"
        Write-InstallerLog "Master backup ID: $masterBackupId" -Level "Info"
        $backupDir = Join-Path $script:BaseDir "backups"
        Write-InstallerLog "Backup location: $backupDir" -Level "Info"
        Write-InstallerLog "If PATH issues occur, contact support with the backup ID above" -Level "Info"
        
    }
    catch {
        Write-InstallerLog "Installation failed: $($_.Exception.Message)" -Level "Error"
        
        if ($_.Exception.InnerException) {
            Write-InstallerLog "Inner exception: $($_.Exception.InnerException.Message)" -Level "Error"
        }
        
        # Attempt emergency PATH restoration if master backup exists
        if ($masterBackupId -and $script:PathBackups.ContainsKey($masterBackupId)) {
            Write-InstallerLog "EMERGENCY: Attempting to restore original PATH due to critical failure" -Level "Error"
            
            $restoreSuccess = Restore-PathEnvironment -BackupId $masterBackupId
            if ($restoreSuccess) {
                Write-InstallerLog "Emergency PATH restoration completed" -Level "Success"
            } else {
                Write-InstallerLog "CRITICAL: Emergency PATH restoration failed!" -Level "Error"
                Write-InstallerLog "Manual recovery required. Backup location: $backupDir" -Level "Error"
            }
        }
        
        exit 1
    }
}

# Execute main function
Invoke-PackageManagerInstallation