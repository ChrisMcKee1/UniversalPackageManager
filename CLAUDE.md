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
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget", "choco")

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
pwsh -File ".\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget") -DryRun -LogLevel Debug
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
   - Log retention settings (only logRetentionDays from Advanced section)
   - PackageManagerInstaller behavior and preferences
   - **Note**: Scheduling is configured via Install-UPM.ps1 parameters, NOT settings.json

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
- **PackageManagers**: Individual manager settings (enabled, args, timeout)
- **Advanced**: Only contains logRetentionDays (other settings removed as unused)
- **PackageManagerInstaller**: Configuration for package manager installation behavior

**Important**: Many configuration sections were removed in recent cleanup:
- **Service settings** (frequency, updateTime) are configured via Install-UPM.ps1 parameters only
- **Logging/UI sections** were unused and removed
- **Advanced settings** reduced to only functional options

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

### Critical Implementation Details

#### PATH Management Safety System
- **Backup System**: All PATH modifications create automatic backups with unique IDs
- **Integrity Validation**: User PATH vs Machine PATH have different validation rules
- **Rollback Capability**: Automatic restoration on failures, manual recovery via `scripts/Restore-PathBackup.ps1`
- **Search Paths**: Package managers use fallback search in common installation locations
- **Session vs Permanent**: Both current session and registry PATH are updated

#### Logging Level Management
- **Default (Info)**: Shows essential progress and results only
- **Debug**: Enables detailed troubleshooting output (use `-LogLevel Debug`)
- **Warning/Error**: Minimal output for automation scenarios
- **Key Principle**: Most verbose messages should use Debug level, not Info

#### Package Manager Specific Issues

**Conda**: 
- Fresh installs require Terms of Service acceptance for non-interactive operation
- Automatically accepts TOS for main Anaconda channels and configures `always_yes = true`
- PATH detection includes both Miniconda and Anaconda installation paths

**Pip**: 
- No native "upgrade all" command - currently lists outdated packages only
- Removed invalid `--format=freeze` with `--outdated` combination

**Winget**: 
- Exit code -1978335188 indicates partial success (some packages failed, some succeeded)
- Teams installation conflicts are common and should be treated as warnings, not failures

#### Error Handling Patterns
- Each module must handle its own failures without affecting other package managers
- Use structured logging with component-specific tags
- PATH operations must never break the system - always validate before applying
- Conda operations must handle TOS acceptance silently

### Version 3.0 Changes (Modular Architecture)

#### Breaking Changes
- **Modular Architecture**: Complete refactor from monolithic to modular design
- **PowerShell 7.0+ Exclusive**: No more Windows PowerShell 5.1 compatibility
- **Clean Reinstall**: Installation script always performs clean reinstalls
- **Emoji-Free**: Removed all Unicode characters for better compatibility

#### New Features
- **10 Focused Modules**: Each 50-80 lines instead of one 2000+ line script
- **PackageManagerInstaller.ps1**: Dedicated script for installing missing package managers with robust PATH handling
- **Dual Log Format**: Human-readable (.log) and structured JSON (.json.log) logs
- **Enhanced Error Handling**: Module-specific isolation with comprehensive try/catch blocks
- **Consistent Interface**: All package manager modules follow the same patterns
- **Better Testing**: Individual modules can be tested and debugged independently
- **PATH Safety**: Comprehensive backup/restore system for environment variable modifications

#### Technical Implementation
- **Module System**: Uses PowerShell's module system with proper exports
- **Error Isolation**: Package manager failures don't cascade to other managers
- **Performance Tracking**: Detailed timing and metrics for each module
- **Configuration Validation**: Enhanced JSON schema validation with defaults merging
- **Modern PowerShell**: Leverages PowerShell 7+ features like $PSStyle and TimeoutSec
- **Safe PATH Operations**: All environment modifications are backed up and validated

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

## Testing and Debugging

### Testing Individual Components
```powershell
# Test specific package managers
pwsh -File "UniversalPackageManager.ps1" -SelectedPackageManagers @("conda") -DryRun -LogLevel Debug

# Test PATH operations safely
pwsh -File "PackageManagerInstaller.ps1" -PackageManagers @("conda") -SkipConfirmation

# Verify PATH backup system
dir backups\PATH-backup-*.json

# Test conda TOS handling specifically
pwsh -c "Import-Module .\modules\UPM.PackageManager.Conda.psm1; Test-CondaAvailable"
```

### Common Debugging Workflows
1. **PATH Issues**: Check `backups\` directory for recovery files, use `scripts\Restore-PathBackup.ps1`
2. **Package Manager Failures**: Run with `-LogLevel Debug` and check both `.log` and `.json.log` files
3. **Conda TOS Errors**: Module automatically handles TOS acceptance - verify with debug logging
4. **Module Isolation**: Test individual modules by importing them directly in PowerShell

### Recent Major Changes (Latest Release)

#### Documentation Accuracy Improvements
- **Fixed scheduling misinformation**: README previously incorrectly stated editing settings.json changes scheduled task timing
- **Parameter name corrections**: Fixed `-PackageManagers` to `-SelectedPackageManagers` throughout documentation
- **Value proposition enhancement**: Added "Why should I care?" section with quantified benefits (2-3 hours/week saved)
- **Clear setup paths**: Separated recommended (existing software) vs power user (all package managers) installation paths

#### Configuration Cleanup (85% Size Reduction)
- **Removed unused Advanced settings**: maxRetries, parallelUpdates, skipFailedPackages, etc. (not used by current code)
- **Removed unused Service settings**: frequency, updateTime (controlled by Install-UPM.ps1 parameters only)
- **Removed unused Logging/UI sections**: All fields were validated but never used by code
- **Kept only functional settings**: enabled/args/timeout in PackageManagers, logRetentionDays in Advanced
- **Documentation now matches reality**: All examples show only settings that actually affect behavior

#### Critical Understanding for Future Development
- **Scheduling is ONLY via Install-UPM.ps1**: The -UpdateTime and -Frequency parameters create the Windows scheduled task directly
- **settings.json does NOT control scheduling**: This was a major documentation error that was corrected
- **Configuration validation vs usage gap**: Many settings were validated by UPM.Configuration.psm1 but never used by main script
- **Parameter naming**: Use `-SelectedPackageManagers` in scripts, `-PackageManagers` for PackageManagerInstaller.ps1 only

### Development Guidelines
- Each module should be 50-80 lines maximum
- All modules must export consistent interfaces
- Use proper try/catch error handling throughout
- No Unicode/emoji characters for compatibility
- Follow PowerShell 7+ best practices
- Include comprehensive help documentation
- Test individual modules independently
- Always use Debug level for verbose logging, Info level for user-visible progress
- PATH operations must include backup/restore capability
- Never break existing PATH - validate before applying changes
- **Always verify configuration settings are actually used before documenting them**
- **Keep documentation accuracy as highest priority** - user trust depends on it