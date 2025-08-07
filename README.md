# Universal Package Manager v3.0 🚀

## ⚡ Why Should I Care?

**Stop manually updating software forever.** UPM v3.0 automatically keeps ALL your Windows software up-to-date across **6 different package managers** - set it up once, forget about it forever.

### 🎯 What This Does For You:
- **⏰ Saves Hours**: No more manual software updates - runs automatically daily at 2 AM
- **🔐 Maximum Security**: Always have the latest security patches across ALL your software
- **🚀 Zero Maintenance**: Works with winget, Chocolatey, Scoop, NPM, pip, and Conda simultaneously  
- **💼 Enterprise-Ready**: Runs with SYSTEM privileges, comprehensive logging, handles corporate environments
- **🛡️ Risk-Free**: Dry-run mode lets you see what would update before making changes

### 📊 Real Impact:
If you have 50+ installed programs (typical developer/power user), you save **2-3 hours per week** of manual updates while ensuring you never miss critical security patches.

> **⚠️ Breaking Change**: Version 3.0 requires PowerShell 7.0+ and uses a completely new modular architecture for better maintainability.

## 📥 Download

### [⬇️ Download Latest Release (v3.0.0)](https://github.com/ChrisMcKee1/UniversalPackageManager/archive/refs/tags/v3.0.0.zip)

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

## 🚀 Quick Start (5 Minutes to Never Update Software Manually Again)

### Prerequisites
- Windows 10/11 or Windows Server 2019+
- **PowerShell 7.0+ (REQUIRED)** - Must be installed before UPM v3.0
- Administrator privileges for installation

> **Important**: UPM v3.0 will NOT work with Windows PowerShell 5.1. Install PowerShell 7+ first:
> - **Microsoft Store**: Search "PowerShell"  
> - **Winget**: `winget install Microsoft.PowerShell`
> - **Direct**: https://github.com/PowerShell/PowerShell/releases

### 🎯 Recommended Path (Works with Existing Software)

**Step 1: Download and Extract**
- Download: [UniversalPackageManager_v3.0.0.zip](https://github.com/ChrisMcKee1/UniversalPackageManager/archive/refs/tags/v3.0.0.zip)
- Extract to: `C:\ProgramData\UniversalPackageManager\`

**Step 2: Setup Automatic Updates** (Right-click → "Run as Administrator")
```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"
```

**Done!** 🎉 Your software will now update automatically every day at 2:00 AM. UPM works with whatever package managers you already have installed.

### ⚡ Power User Path (Get All Package Managers)

If you want to maximize your software management capabilities:

**Step 1: Download and Extract** (same as above)

**Step 2: Install All Package Managers** (Optional but recommended)
```powershell
# Installs winget, Chocolatey, Scoop, Node.js, Python, and Miniconda automatically
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1"
```

**Step 3: Setup Automatic Updates**
```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"
```

**Result**: You now have access to 50,000+ packages across 6 package managers, all updating automatically!

## 🎮 Usage Scenarios

### 🔧 Common Operations

```powershell
# 🚀 Run immediate update of all packages (great for testing)
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1"

# 🔍 See what would be updated without making changes (safe to run anytime)  
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -DryRun

# 🎯 Update only specific package managers (when you have issues with one)
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget", "choco")

# ⚙️ Open configuration editor (customize settings)
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Configure

# 🔍 Check system status (see what's installed and working)
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Status

# 🐛 Troubleshoot issues with detailed logging
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -LogLevel Debug
```

### 💡 Real-World Scenarios

**Scenario 1: New Developer Machine Setup**
```powershell
# Install all development tools and package managers
.\PackageManagerInstaller.ps1 -Force

# Set up automated updates
.\Install-UPM.ps1

# Result: Full development environment with automatic maintenance
```

**Scenario 2: Maintenance Window Testing**  
```powershell
# See what updates are available before maintenance window
.\UniversalPackageManager.ps1 -DryRun

# During maintenance window, update everything
.\UniversalPackageManager.ps1

# Check for any failures
.\UniversalPackageManager.ps1 -Operation Status
```

**Scenario 3: Troubleshooting Package Manager Issues**
```powershell
# Test specific package manager that's having problems
.\UniversalPackageManager.ps1 -SelectedPackageManagers @("conda") -DryRun -LogLevel Debug

# View recent logs
Get-Content .\logs\UPM-*.log | Select-Object -Last 50
```

### 🎛️ Advanced Configuration Options

**Custom Update Schedule**
```powershell
# Run updates weekly on Sunday at 3:30 AM instead of daily
.\Install-UPM.ps1 -Frequency Weekly -UpdateTime "03:30"

# Run updates daily at 6:00 PM (good for always-on workstations)  
.\Install-UPM.ps1 -Frequency Daily -UpdateTime "18:00"
```

**Package Manager Installation Flexibility**
```powershell
# Install everything automatically (recommended for new machines)
.\PackageManagerInstaller.ps1                                    

# Install only specific package managers with confirmation prompts
.\PackageManagerInstaller.ps1 -PackageManagers @("choco", "scoop")  

# Force clean reinstall of everything (good for fixing corrupted installations)
.\PackageManagerInstaller.ps1 -Force -SkipConfirmation          

# Fix specific package manager installation
.\PackageManagerInstaller.ps1 -PackageManagers @("conda") -Force   
```

**What Each Package Manager Gives You:**
- **winget**: Windows Store apps, Microsoft tools, development software  
- **Chocolatey**: Largest Windows package repository (8,000+ packages)
- **Scoop**: Developer tools, portable apps, command-line utilities
- **npm**: JavaScript/Node.js packages and development tools
- **pip**: Python packages and data science tools  
- **conda**: Scientific computing, data science, AI/ML packages

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
    "taskName": "Universal Package Manager v3.0",
    "runAsSystem": true,
    "highestPrivileges": true
  }
}
```

> **Note**: Scheduling settings (`updateTime`, `frequency`) must be configured during installation using Install-UPM.ps1 parameters, not through settings.json.

### Advanced Settings (v3.0)
```json
{
  "Advanced": {
    "logRetentionDays": 30
  }
}
```

### PackageManagerInstaller Settings
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

## 📊 Configuration Options

| Setting | Description | Default | Options |
|---------|-------------|---------|---------|
| `enabled` | Enable/disable package manager | `true` | `true`, `false` |
| `args` | Additional command line arguments | varies | Any valid arguments |
| `timeout` | Timeout in seconds | varies | Any positive integer |
| `logRetentionDays` | Number of days to keep log files | `30` | Any positive integer |
| `defaultPackageManagers` | Package managers to install by default | `["all"]` | Array of package manager names |
| `autoAccept` | Automatically accept installation prompts | `true` | `true`, `false` |
| `forceReinstall` | Force reinstall of package managers | `false` | `true`, `false` |

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
A: Rerun the Install-UPM.ps1 script with new `-UpdateTime` and `-Frequency` parameters, or use the Task Scheduler (`taskschd.msc`) to modify the "Universal Package Manager v3.0" task directly.

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
pwsh -File ".\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget") -DryRun -LogLevel Debug

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
