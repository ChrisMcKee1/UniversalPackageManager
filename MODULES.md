# Universal Package Manager v3.0 - Modular Architecture

This document describes the modular architecture introduced in Universal Package Manager v3.0.

## Architecture Overview

UPM v3.0 has been completely refactored from a single monolithic script (~2000+ lines) into a modular architecture with focused, maintainable components (~50-80 lines each).

## Module Structure

```
C:\ProgramData\UniversalPackageManager\
├── UniversalPackageManager.ps1          # Main orchestrator (318 lines)
├── UniversalPackageManager-old.ps1      # Backup of original monolithic script
├── modules\                              # Module directory
│   ├── UPM.Logging.psm1                 # Core logging functionality
│   ├── UPM.Configuration.psm1           # Configuration management
│   ├── UPM.ProcessExecution.psm1        # Process execution with timeouts
│   ├── UPM.PackageManager.Winget.psm1   # Windows Package Manager
│   ├── UPM.PackageManager.Chocolatey.psm1 # Chocolatey package manager
│   ├── UPM.PackageManager.Scoop.psm1    # Scoop package manager
│   ├── UPM.PackageManager.Npm.psm1      # NPM global packages
│   ├── UPM.PackageManager.Pip.psm1      # Python pip packages
│   └── UPM.PackageManager.Conda.psm1    # Conda package manager
├── config\
│   └── settings.json                     # Configuration file
└── logs\                                 # Log directory
    ├── UPM-YYYYMMDD-HHMMSS.log         # Human-readable logs
    └── UPM-YYYYMMDD-HHMMSS.json.log    # Structured JSON logs
```

## Core Modules

### UPM.Logging.psm1
**Purpose**: Centralized logging with structured data and performance metrics

**Key Functions**:
- `Initialize-UPMLogging` - Setup logging system
- `Write-UPMLog` - Write structured log entries
- `Start-UPMTimer` / `Stop-UPMTimer` - Performance timing
- `Remove-OldLogFiles` - Log cleanup

**Features**:
- JSON structured logging
- ANSI color console output
- Performance metrics and timing
- Automatic log rotation
- PowerShell 7+ $PSStyle support
- No emoji/Unicode characters for Windows PowerShell 5.1 compatibility

### UPM.Configuration.psm1
**Purpose**: Configuration file management and validation

**Key Functions**:
- `Initialize-UPMConfiguration` - Load and validate config
- `Get-UPMConfiguration` - Get current configuration
- `Get-UPMPackageManagers` - Get enabled package managers
- `Update-UPMConfiguration` - Update configuration values

**Features**:
- JSON configuration with schema validation
- Default configuration merging
- Configuration validation with warnings
- Automatic configuration file creation

### UPM.ProcessExecution.psm1
**Purpose**: Safe process execution with PowerShell 7+ features

**Key Functions**:
- `Invoke-UPMProcess` - Execute process with timeout
- `Test-UPMCommand` - Test command availability
- `Invoke-UPMProcessWithRetry` - Process execution with retry logic

**Features**:
- PowerShell 7+ TimeoutSec parameter
- Comprehensive error handling
- Process monitoring and control
- Retry logic with configurable delays

## Package Manager Modules

Each package manager has its own dedicated module following a consistent interface:

### Standard Interface
All package manager modules implement these functions:
- `Test-[PackageManager]Available` - Check if package manager is installed
- `Update-[PackageManager]Packages` - Update all packages
- `Get-[PackageManager]Info` - Get package manager information

### UPM.PackageManager.Winget.psm1
**Package Manager**: Windows Package Manager (winget)
**Additional Functions**:
- `Get-WingetPackages` - List installed packages
- `Get-WingetUpgradablePackages` - List upgradeable packages
- `Install-WingetPackage` - Install specific package
- `Uninstall-WingetPackage` - Uninstall specific package

### UPM.PackageManager.Chocolatey.psm1
**Package Manager**: Chocolatey
**Additional Functions**:
- `Get-ChocolateyPackages` - List installed packages
- `Get-ChocolateyUpgradablePackages` - List upgradeable packages
- `Install-ChocolateyPackage` - Install specific package
- `Uninstall-ChocolateyPackage` - Uninstall specific package
- `Update-ChocolateyItself` - Update Chocolatey itself

### Other Package Manager Modules
- `UPM.PackageManager.Scoop.psm1` - Scoop command-line installer
- `UPM.PackageManager.Npm.psm1` - NPM global packages
- `UPM.PackageManager.Pip.psm1` - Python pip packages
- `UPM.PackageManager.Conda.psm1` - Conda data science packages

## Main Orchestrator

### UniversalPackageManager.ps1
The main script is now a lightweight orchestrator (318 lines vs 2000+ in the monolithic version) that:
- Imports all required modules
- Initializes the logging and configuration systems
- Maps package managers to their respective module functions
- Coordinates execution across all package managers
- Provides three main operations: Update, Status, Configure

**Key Functions**:
- `Initialize-UPM` - System initialization
- `Invoke-PackageManagerUpdate` - Execute update for specific package manager
- `Invoke-UpdateOperation` - Coordinate updates across all package managers
- `Invoke-StatusOperation` - Display system status
- `Invoke-ConfigureOperation` - Open configuration editor

## Benefits of Modular Architecture

### 1. **Maintainability**
- Each module has a single responsibility
- Easy to locate and fix issues
- Clear separation of concerns
- Individual modules can be tested independently

### 2. **Reliability** 
- Emoji/Unicode issues resolved at the module level
- Consistent error handling patterns
- Better isolation of package manager specific logic
- Reduced risk of cascade failures

### 3. **Extensibility**
- Easy to add new package managers
- Consistent interface patterns
- Modular configuration management
- Plugin-like architecture

### 4. **Performance**
- Modules loaded only when needed
- Better memory management
- Easier to optimize individual components
- Parallel execution possibilities

### 5. **Testing**
- Individual modules can be unit tested
- Mock dependencies easily
- Isolated testing environments
- Better code coverage

## Emoji/Unicode Compatibility

All modules have been designed to avoid emoji and Unicode characters that caused issues with Windows PowerShell 5.1. Instead of emojis, we use:
- `SUCCESS:` instead of ✅
- `ERROR:` instead of ❌  
- `WARNING:` instead of ⚠️
- Descriptive text instead of decorative emojis

## PowerShell 7+ Exclusive Features

The modular architecture takes advantage of PowerShell 7+ features:
- `#Requires -Version 7.0` in all modules
- `Start-Process -TimeoutSec` parameter
- `$PSStyle` for ANSI colors
- Enhanced JSON handling with `-AsHashtable`
- Modern error handling patterns
- Advanced function parameter validation

## Migration from v2.x

The modular v3.0 maintains compatibility with v2.x configuration files while providing enhanced features. The old monolithic script is preserved as `UniversalPackageManager-old.ps1` for reference.

## Usage Examples

```powershell
# Standard update operation
pwsh -File "UniversalPackageManager.ps1"

# Update specific package managers only
pwsh -File "UniversalPackageManager.ps1" -PackageManagers @("winget", "choco")

# Dry run to see what would be updated
pwsh -File "UniversalPackageManager.ps1" -DryRun

# Status check
pwsh -File "UniversalPackageManager.ps1" -Operation Status

# Configure settings
pwsh -File "UniversalPackageManager.ps1" -Operation Configure

# Debug logging
pwsh -File "UniversalPackageManager.ps1" -LogLevel Debug
```

## Future Enhancements

The modular architecture enables future enhancements such as:
- Additional package managers (brew, apt, yum, etc.)
- Parallel package manager execution
- Package manager dependency resolution
- Advanced scheduling and orchestration
- Remote package manager management
- Configuration templates and profiles