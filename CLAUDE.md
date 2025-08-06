# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Universal Package Manager (UPM) v3.0 is a **PowerShell 7+ exclusive** automation system that centralizes package management across multiple Windows package managers. It runs as a Windows scheduled task with SYSTEM privileges to automatically update packages from winget, Chocolatey, Scoop, npm, pip, and Conda.

**⚠️ Breaking Changes**: Version 3.0 requires PowerShell 7.0+, uses modular architecture, and always performs clean reinstalls.

## Key Commands

### Manual Operations
```powershell
# Run manual update of all packages
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1"

# Test what would be updated (dry run)
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -DryRun

# Update only specific package managers
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -PackageManagers @("winget", "choco")

# Open configuration editor
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Configure

# Run with debug logging
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -LogLevel Debug
```

### Installation and Setup
```powershell
# IMPORTANT: Upgrade from previous versions (removes old scheduled tasks)
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"

# Install with custom schedule  
.\Install-UPM.ps1 -Frequency Weekly -UpdateTime "03:30"

# Install missing package managers (auto-accepts by default)
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1"

# Install specific package managers (prompts for confirmation)
.\PackageManagerInstaller.ps1 -PackageManagers @("choco", "scoop")

# Force reinstall all package managers without prompts
.\PackageManagerInstaller.ps1 -Force -SkipConfirmation

# Test installation with modern progress bars
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -DryRun -LogLevel Debug
```

### Troubleshooting Commands
```powershell
# Check scheduled task status
Get-ScheduledTask -TaskName "Universal Package Manager" | Get-ScheduledTaskInfo

# View recent log entries
Get-Content (Get-ChildItem "C:\ProgramData\UniversalPackageManager\logs\UPM-*.log" | Sort-Object CreationTime | Select-Object -Last 1).FullName -Tail 50

# Test individual package managers
pwsh -File ".\UniversalPackageManager.ps1" -PackageManagers @("winget") -DryRun -LogLevel Debug
```

## Architecture

### Core Components

1. **UniversalPackageManager.ps1** - Main orchestration script that:
   - Manages configuration loading and validation
   - Executes package manager updates with timeout and retry logic
   - Provides comprehensive logging with rotation
   - Supports dry-run mode for testing

2. **Install-UPM.ps1** - Installation script that:
   - Creates Windows scheduled task with SYSTEM privileges  
   - Sets up proper directory permissions
   - Configures automated daily/weekly updates
   - Validates PowerShell 7+ availability

3. **config/settings.json** - JSON configuration controlling:
   - Individual package manager enable/disable states
   - Timeout values and command arguments per package manager
   - Service scheduling (frequency, time)
   - Advanced settings (retries, parallel execution)
   - PackageManagerInstaller behavior and preferences

4. **PackageManagerInstaller.ps1** - Package manager installer that:
   - Installs missing package managers (winget, Chocolatey, Scoop, Node.js, Python, Miniconda)
   - Auto-accepts installation when no specific packages are selected
   - Reads configuration from settings.json for default behaviors
   - Supports force reinstall and selective installation

### Package Manager Integration

Each package manager has its own update function following a consistent pattern:
- `Update-WingetPackages()` - Windows Package Manager with individual package progress tracking
- `Update-ChocolateyPackages()` - Chocolatey with self-update + all packages
- `Update-ScoopPackages()` - Scoop with bucket update + package upgrade
- `Update-NpmPackages()` - NPM global packages with self-update
- `Update-PipPackages()` - Python packages with outdated package detection
- `Update-CondaPackages()` - Conda with environment updates

### Execution Flow

1. Initialize logging with timestamped files (auto-rotated, keeps last 30)
2. Load configuration from JSON with fallback to defaults
3. Check which package managers are available and enabled
4. Execute updates sequentially or in parallel (configurable)
5. Handle errors with retry logic and optional failure skip
6. Generate comprehensive summary with success/failure counts

### Security Model

- Runs as SYSTEM account with highest privileges
- Uses Windows Task Scheduler for automation
- All operations logged for audit trail
- Configuration uses standard Windows ACLs
- No network communication except through package managers

## Configuration

The enhanced `config/settings.json` supports the modular architecture:

#### Configuration Sections
- **_metadata**: Version and schema information for v3.0
- **PackageManagers**: Individual manager settings with module-specific configurations
- **Service**: Scheduling and task configuration
- **Advanced**: Retry logic, performance settings, error handling
- **Logging**: Enhanced logging configuration for dual format output
- **UI**: Display settings (emojis disabled by default)
- **PackageManagerInstaller**: Configuration for package manager installation behavior

#### Features
- **Automatic Creation**: Generated with sensible defaults if missing
- **Schema Validation**: Enhanced validation with warning system
- **Default Merging**: User settings merged with comprehensive defaults
- **Module Integration**: Each package manager module reads its own configuration section

Configuration is automatically created with enhanced defaults and can be edited via the `-Operation Configure` parameter.

#### PackageManagerInstaller Configuration

The `PackageManagerInstaller` section controls the behavior of the PackageManagerInstaller.ps1 script:

```json
{
  "PackageManagerInstaller": {
    "defaultPackageManagers": ["all"],
    "autoAccept": true,
    "forceReinstall": false,
    "preferredInstallMethods": {
      "winget": "store",
      "nodejs": "winget",
      "python": "winget",
      "conda": "winget"
    }
  }
}
```

**Settings:**
- `defaultPackageManagers`: Which package managers to install when no command-line arguments provided (default: `["all"]`)
- `autoAccept`: Automatically accept installation without user confirmation (default: `true`)
- `forceReinstall`: Force reinstall even if package managers are already installed (default: `false`)
- `preferredInstallMethods`: Preferred installation method for each package manager

**Priority:** Command-line parameters override configuration file settings, which override hardcoded defaults.

## Development Notes

### Version 3.0 Changes (Modular Architecture)

#### Breaking Changes
- **Modular Architecture**: Complete refactor from monolithic to modular design
- **PowerShell 7.0+ Exclusive**: No more Windows PowerShell 5.1 compatibility
- **Clean Reinstall**: Installation script always performs clean reinstalls
- **Emoji-Free**: Removed all Unicode characters for better compatibility

#### New Features
- **10 Focused Modules**: Each 50-80 lines instead of one 2000+ line script
- **PackageManagerInstaller.ps1**: Dedicated script for installing missing package managers
- **Dual Log Format**: Human-readable (.log) and structured JSON (.json.log) logs
- **Enhanced Error Handling**: Module-specific isolation with comprehensive try/catch blocks
- **Consistent Interface**: All package manager modules follow the same patterns
- **Better Testing**: Individual modules can be tested and debugged independently

#### Technical Implementation
- **Module System**: Uses PowerShell's module system with proper exports
- **Error Isolation**: Package manager failures don't cascade to other managers
- **Performance Tracking**: Detailed timing and metrics for each module
- **Configuration Validation**: Enhanced JSON schema validation with defaults merging
- **Modern PowerShell**: Leverages PowerShell 7+ features like $PSStyle and TimeoutSec

### File Structure
```
C:\ProgramData\UniversalPackageManager\
├── UniversalPackageManager.ps1     # Main orchestrator (318 lines)
├── Install-UPM.ps1                 # Installation script
├── PackageManagerInstaller.ps1     # Package manager installer
├── modules\                         # Module directory
│   ├── UPM.*.psm1                  # 9 focused modules
├── config\settings.json            # Enhanced configuration
└── logs\                           # Dual format logs
```

### Development Guidelines
- Each module should be 50-80 lines maximum
- All modules must export consistent interfaces
- Use proper try/catch error handling throughout
- No Unicode/emoji characters for compatibility
- Follow PowerShell 7+ best practices
- Include comprehensive help documentation
- Test individual modules independently