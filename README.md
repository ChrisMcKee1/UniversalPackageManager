# Universal Package Manager v3.0 🚀

A comprehensive **PowerShell 7+ exclusive** solution that automatically manages and updates packages across multiple package managers on Windows systems with **modular architecture**, enhanced logging, and improved reliability.

> **⚠️ Breaking Change**: Version 3.0 requires PowerShell 7.0+ and uses a completely new modular architecture for better maintainability.

## 📥 Download

### [⬇️ Download Latest Release (v3.0.0)](https://github.com/ChrisMcKee1/UniversalPackageManager/releases/download/v3.0.0/UniversalPackageManager_v3.0.0.zip)

**Direct Download**: https://github.com/ChrisMcKee1/UniversalPackageManager/releases/latest

## 🚀 Overview

The Universal Package Manager (UPM) v3.0 consolidates package management across all major Windows package managers into a single, automated system powered exclusively by PowerShell 7+. It features a **modular architecture** with focused, maintainable components, runs as a scheduled task with full SYSTEM privileges, and includes structured logging with comprehensive error handling.

## 🆕 What's New in v3.0

### 🔥 Breaking Changes
- **PowerShell 7.0+ Required**: No longer compatible with Windows PowerShell 5.1
- **Scheduled Task Renamed**: Now "Universal Package Manager v3.0" (auto-upgraded during install)

### ✨ New Features
- **🏗️ Modular Architecture**: Organized into focused modules (~50-80 lines each) for better maintainability
- **📊 Structured Logging**: JSON output with performance metrics and telemetry
- **🌈 ANSI Colors**: Beautiful console output using PowerShell 7+ $PSStyle
- **⚡ Enhanced Performance**: Native PowerShell 7+ timeout support and better process handling
- **🔍 Rich Diagnostics**: Detailed error tracking with context and timing information
- **🛠️ Package Manager Installer**: Dedicated script to install/upgrade missing package managers
- **🔄 Clean Reinstall**: Installation script always performs clean reinstalls for reliability
- **✅ Emoji-Free**: Resolved all Unicode compatibility issues for better reliability

## 📦 Supported Package Managers

- **Windows Package Manager (winget)** - Microsoft's official package manager
- **Chocolatey** - Popular Windows package manager  
- **Scoop** - Command-line installer for Windows
- **NPM** - Node.js package manager (global packages)
- **pip** - Python package installer
- **Conda** - Python/R data science package manager

## 🎯 Key Features (v3.0)

- **🤖 Fully Automated**: Runs daily at 2:00 AM by default with PowerShell 7+
- **🔐 Administrative Privileges**: Executes with SYSTEM account and highest privileges
- **🎨 Modern UI**: Beautiful progress bars with emoji indicators and real-time estimates
- **📊 Enhanced Logging**: Structured JSON logging with performance metrics and telemetry
- **🛡️ Robust Error Handling**: Advanced timeout protection, retry logic, and comprehensive error tracking
- **⚙️ Highly Configurable**: Enhanced JSON configuration with v3.0 features
- **🔄 Dry Run Support**: Test operations without making changes
- **⚡ Performance Optimized**: PowerShell 7+ exclusive for maximum speed and reliability
- **🌈 ANSI Colors**: Modern console output with $PSStyle support

## 📁 File Structure

```
C:\ProgramData\UniversalPackageManager\
├── UniversalPackageManager.ps1     # Main orchestrator script (modular)
├── Install-UPM.ps1                 # Installation and setup script
├── PackageManagerInstaller.ps1     # Package manager installer script
├── README.md                        # This documentation
├── MODULES.md                       # Modular architecture documentation
├── modules\                         # Module directory
│   ├── UPM.Logging.psm1            # Core logging functionality
│   ├── UPM.Configuration.psm1      # Configuration management
│   ├── UPM.ProcessExecution.psm1   # Process execution with timeouts
│   ├── UPM.PackageManager.Winget.psm1      # Windows Package Manager
│   ├── UPM.PackageManager.Chocolatey.psm1  # Chocolatey package manager
│   ├── UPM.PackageManager.Scoop.psm1       # Scoop package manager
│   ├── UPM.PackageManager.Npm.psm1         # NPM global packages
│   ├── UPM.PackageManager.Pip.psm1         # Python pip packages
│   └── UPM.PackageManager.Conda.psm1       # Conda package manager
├── config\
│   └── settings.json               # Configuration file
└── logs\                           # Log files (auto-rotated)
    ├── UPM-YYYYMMDD-HHMMSS.log    # Human-readable logs
    └── UPM-YYYYMMDD-HHMMSS.json.log  # Structured JSON logs
```

## 🚀 Quick Start

### Prerequisites
- Windows 10/11 or Windows Server 2019+
- **PowerShell 7.0+ (REQUIRED)** - Must be installed before UPM v3.0
- Administrator privileges for installation

> **Important**: UPM v3.0 will NOT work with Windows PowerShell 5.1. Install PowerShell 7+ first:
> - **Microsoft Store**: Search "PowerShell"
> - **Direct Download**: https://github.com/PowerShell/PowerShell/releases
> - **Winget**: `winget install Microsoft.PowerShell`

### Installation

1. **Download the latest release** from [GitHub Releases](https://github.com/ChrisMcKee1/UniversalPackageManager/releases/latest) and extract the ZIP file to `C:\ProgramData\UniversalPackageManager\`
   - Direct download: [UniversalPackageManager_v3.0.0.zip](https://github.com/ChrisMcKee1/UniversalPackageManager/releases/download/v3.0.0/UniversalPackageManager_v3.0.0.zip)

2. **(Optional) Install missing package managers**:
   ```powershell
   # Install all supported package managers (auto-proceeds without confirmation)
   pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1"
   
   # Install specific ones (will prompt for confirmation)
   pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1" -PackageManagers @("choco", "scoop")
   
   # Force reinstall without any prompts
   pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1" -Force -SkipConfirmation
   ```

3. **Run the UPM installer** as Administrator (always performs clean reinstall):
   ```powershell
   pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"
   ```
   > The installer always removes existing scheduled tasks and creates "Universal Package Manager v3.0" fresh

4. **That's it!** The system will now automatically update all your packages daily at 2:00 AM using the modular PowerShell 7+ architecture.

## 🎮 Usage

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

### Installation Options

```powershell
# UPM Installation Options
.\Install-UPM.ps1 -Frequency Weekly -UpdateTime "03:30"

# Package Manager Installer Options
.\PackageManagerInstaller.ps1                                    # Install all (auto-accept)
.\PackageManagerInstaller.ps1 -PackageManagers @("choco", "scoop")  # Selective (prompts)
.\PackageManagerInstaller.ps1 -Force -SkipConfirmation          # Force reinstall all
.\PackageManagerInstaller.ps1 -PackageManagers @("winget") -Force   # Force specific ones
```

## ⚙️ Configuration

Edit `config\settings.json` to customize behavior:

### Package Manager Settings
```json
{
  "PackageManagers": {
    "winget": {
      "enabled": true,
      "args": "--accept-source-agreements --accept-package-agreements --silent",
      "timeout": 600
    },
    "choco": {
      "enabled": true,
      "args": "-y --limit-output",
      "timeout": 900
    }
  }
}
```

### Service Settings
```json
{
  "Service": {
    "enabled": true,
    "updateTime": "02:00",
    "frequency": "Daily"
  }
}
```

### Advanced Settings (v3.0)
```json
{
  "Advanced": {
    "maxRetries": 3,
    "retryDelay": 30,
    "skipFailedPackages": true,
    "parallelUpdates": false,
    "maxParallel": 4,
    "enableStructuredLogging": true,
    "enablePerformanceMetrics": true,
    "logRetentionDays": 30
  }
}
```

### New v3.0 Configuration Sections
```json
{
  "Logging": {
    "defaultLevel": "Info",
    "enableJsonLogs": true,
    "enableConsoleLogs": true,
    "enableFileRotation": true,
    "maxLogFiles": 30
  },
  "UI": {
    "progressStyle": "Minimal",
    "enableEmojis": false,
    "enableColors": true,
    "progressMaxWidth": 120
  },
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

> **Note**: Emojis are disabled by default in v3.0 for improved compatibility and reliability.

## 📊 Configuration Options

| Setting | Description | Default | Options |
|---------|-------------|---------|---------|
| `enabled` | Enable/disable package manager | `true` | `true`, `false` |
| `args` | Additional command line arguments | varies | Any valid arguments |
| `timeout` | Timeout in seconds | varies | Any positive integer |
| `maxRetries` | Number of retry attempts | `3` | Any positive integer |
| `retryDelay` | Delay between retries (seconds) | `30` | Any positive integer |
| `skipFailedPackages` | Continue if a package manager fails | `true` | `true`, `false` |
| `updateTime` | Daily update time | `"02:00"` | `"HH:MM"` format |
| `frequency` | Update frequency | `"Daily"` | `"Daily"`, `"Weekly"` |

## 📝 Enhanced Logging (v3.0)

### Log Files
- **Location**: `C:\ProgramData\UniversalPackageManager\logs\`
- **Human-readable Format**: `UPM-YYYYMMDD-HHMMSS.log`
- **Structured JSON Format**: `UPM-YYYYMMDD-HHMMSS.json.log` (new in v3.0)
- **Retention**: Configurable (default 30 log files)
- **Levels**: Debug, Info, Warning, Error, Success

### New v3.0 Logging Features
- **🏗️ Structured Data**: All log entries include metadata, timing, and context
- **📊 Performance Metrics**: Execution times, package counts, success rates
- **🔍 Rich Context**: Process IDs, thread IDs, component tracking
- **🎨 ANSI Colors**: Beautiful console output using PowerShell 7+ $PSStyle
- **📈 Telemetry**: Detailed diagnostics for troubleshooting
- **📁 Dual Format**: Human-readable and JSON logs for different use cases

### Log Level Hierarchy
- **Debug**: Everything including structured data (most verbose)
- **Info**: Normal operations, warnings, errors, successes with context
- **Warning**: Warnings, errors, successes with performance data
- **Error**: Errors and successes with full diagnostic information

## 🔧 Troubleshooting

### Common Issues

**Q: Some package managers aren't being updated**  
A: Use the PackageManagerInstaller.ps1 script to install missing package managers, or check if they're properly installed and accessible.

**Q: Updates are failing with permission errors**  
A: The installer always performs a clean reinstall. Run Install-UPM.ps1 again to ensure proper configuration.

**Q: Want to change the update schedule**  
A: Edit `config\settings.json` or use the Task Scheduler (`taskschd.msc`) to modify the "Universal Package Manager v3.0" task.

**Q: Need to see what's happening during updates**  
A: Check both the human-readable (.log) and JSON (.json.log) files in the `logs\` folder, or run manually with `-LogLevel Debug`.

**Q: Missing package managers**  
A: Run the PackageManagerInstaller.ps1 script to automatically install winget, Chocolatey, Scoop, Node.js, Python, and Miniconda.

### Manual Troubleshooting

#### Open Task Scheduler

1. Press the `Windows + R` or open `Run`
2. Paste
    ```text
    taskschd.msc
    ```
3. Press Ok then find your task named `Universal Package Manager v3.0`

#### Use Powershell

```powershell
# Test individual package managers
pwsh -File ".\UniversalPackageManager.ps1" -PackageManagers @("winget") -DryRun -LogLevel Debug

# Check system status
pwsh -File ".\UniversalPackageManager.ps1" -Operation Status

# Install missing package managers
pwsh -File ".\PackageManagerInstaller.ps1" -PackageManagers @("choco", "scoop")

# View recent log entries (human-readable)
Get-Content (Get-ChildItem .\logs\UPM-*.log | Sort-Object CreationTime | Select-Object -Last 1).FullName -Tail 50

# View structured JSON logs
Get-Content (Get-ChildItem .\logs\UPM-*.json.log | Sort-Object CreationTime | Select-Object -Last 1).FullName -Tail 10 | ConvertFrom-Json

# Check scheduled task status (v3.0)
Get-ScheduledTask -TaskName "Universal Package Manager v3.0" | Get-ScheduledTaskInfo
```

## 🔐 Security

- Runs with **SYSTEM** account privileges for maximum compatibility
- Uses **Highest** execution level for administrative operations
- All operations are logged for audit trail
- Configuration files use standard Windows ACLs
- No network communication except through package managers

## 🔄 Uninstalling

To remove the Universal Package Manager:

```powershell
# Remove scheduled task (v3.0)
Unregister-ScheduledTask -TaskName "Universal Package Manager v3.0" -Confirm:$false

# Remove files (optional)
Remove-Item -Recurse -Force "C:\ProgramData\UniversalPackageManager"
```

> **Note**: The v3.0 installer automatically handles cleanup of old tasks during installation.

## 📞 Support

For issues or questions:
1. Check both human-readable (.log) and JSON (.json.log) files in the `logs\` folder
2. Run with `-LogLevel Debug` for detailed output
3. Test with `-DryRun` to see what would happen
4. Use `-Operation Status` to check system status
5. Run `PackageManagerInstaller.ps1` to install missing package managers
6. Verify your configuration in `config\settings.json`
7. Review the modular architecture documentation in `MODULES.md`

## 📄 License

This software is provided as-is for educational and operational purposes.

## 🏗️ Architecture

UPM v3.0 features a completely new **modular architecture** that breaks the previous monolithic script (~2000+ lines) into focused, maintainable modules (~50-80 lines each). See `MODULES.md` for detailed architecture documentation.

### Key Benefits:
- **Maintainability**: Each module has a single responsibility
- **Reliability**: Issues in one package manager don't affect others
- **Extensibility**: Easy to add new package managers
- **Testing**: Individual modules can be tested independently

---

**🎉 Enjoy automated package management with modern, maintainable architecture!**
