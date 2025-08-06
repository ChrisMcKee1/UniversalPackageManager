# Universal Package Manager Usage Guide

## Basic Usage

### Run with clean output (default)
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1"
```

### Run with detailed debugging information
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -LogLevel Debug
```

### Run specific package managers only
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget", "npm")
```

### Check what would be updated without making changes
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -DryRun
```

## Log Levels

- **Info** (default): Shows essential progress and results
- **Warning**: Shows Info + warnings  
- **Error**: Shows only errors and critical messages
- **Debug**: Shows all detailed debugging information

## Package Manager Installer

### Install missing package managers
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1"
```

### Install specific package managers
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1" -PackageManagers @("conda", "scoop")
```

## Operations

### Update packages (default)
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Update
```

### Check status of package managers
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Status
```

### Configure settings
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Configure
```

## Examples

### Quiet operation with minimal output
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -LogLevel Warning -Silent
```

### Verbose debugging for troubleshooting
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -LogLevel Debug
```

### Update only npm and pip packages
```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -SelectedPackageManagers @("npm", "pip")
```