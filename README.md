# Universal Package Manager v3.0.2

Universal Package Manager (UPM) is a PowerShell 7+ automation system for keeping Windows software updated across multiple package managers from one scheduled task.

## What it does

- Updates packages across winget, Chocolatey, Scoop, npm, pip, and Conda
- Runs as a scheduled task under `NT AUTHORITY\SYSTEM`
- Uses a modular PowerShell architecture with focused package manager modules
- Supports dry runs, status checks, structured logging, and configurable timeouts
- Includes an installer for missing package managers

## Current platform status

UPM is designed for system-wide automation. In the current v3.0.2 implementation, 5 of the 6 supported package managers work in SYSTEM context.

| Package manager | Status in SYSTEM context | Notes |
| --- | --- | --- |
| winget | Working | Searches well-known WindowsApps locations when not in PATH |
| Chocolatey | Working | System-wide by design |
| npm | Working | Uses `npm.cmd` detection to avoid PowerShell script resolution issues |
| pip | Working | Searches system-wide Python installation paths |
| Conda | Working | Uses system-wide install paths and avoids the `/AddToPath=1` CVE-2022-26526 issue |
| Scoop | User-only | Scoop remains user-scoped by design |

## Requirements

- Windows 10/11 or Windows Server 2019+
- PowerShell 7.0+
- Administrator privileges for installation and scheduled-task setup

## Repository layout

```text
UniversalPackageManager/
├── UniversalPackageManager.ps1      # Main orchestrator
├── Install-UPM.ps1                  # Scheduled-task installer
├── PackageManagerInstaller.ps1      # Installs or upgrades supported package managers
├── Migrate-TaskName.ps1             # Renames old v3.0.x scheduled task names
├── README.md
├── USAGE.md
├── MODULES.md
├── CONDA-RESEARCH-FINDINGS.md
├── config/
│   └── settings.json
├── modules/
│   ├── UPM.Logging.psm1
│   ├── UPM.Configuration.psm1
│   ├── UPM.ProcessExecution.psm1
│   ├── UPM.PackageManager.Winget.psm1
│   ├── UPM.PackageManager.Chocolatey.psm1
│   ├── UPM.PackageManager.Scoop.psm1
│   ├── UPM.PackageManager.Npm.psm1
│   ├── UPM.PackageManager.Pip.psm1
│   └── UPM.PackageManager.Conda.psm1
└── scripts/
    └── Restore-PathBackup.ps1
```

## Quick start

1. Extract the repository contents to `C:\ProgramData\UniversalPackageManager`
2. Open PowerShell 7 as Administrator
3. Optionally install package managers:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1"
```

4. Install the scheduled task:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"
```

By default, the installer creates a scheduled task named `Universal Package Manager` that runs daily at `02:00` with highest privileges as `SYSTEM`.

## Common commands

### Run updates immediately

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1"
```

### Preview updates without changing anything

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -DryRun
```

### Update only selected package managers

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget", "choco")
```

### Show package manager status

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Status
```

### Open the configuration file

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Configure
```

### Run with debug logging

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -LogLevel Debug
```

## Installation and scheduling

`Install-UPM.ps1` always performs a clean reinstall of the scheduled task before creating a new one.

### Change the schedule

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1" -Frequency Weekly -UpdateTime "03:30"
```

Supported values:

- `-Frequency Daily`
- `-Frequency Weekly` (runs on Sunday)
- `-UpdateTime "HH:MM"`

### Upgrade from older v3.0.x task names

If you still have the older task named `Universal Package Manager v3.0`, run:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Migrate-TaskName.ps1"
```

## Package manager installer

`PackageManagerInstaller.ps1` can install or upgrade these targets:

- `winget`
- `choco`
- `scoop`
- `nodejs`
- `python`
- `conda`
- `all`

Examples:

```powershell
# Install everything using configuration defaults
pwsh -ExecutionPolicy Bypass -File ".\PackageManagerInstaller.ps1"

# Reinstall only Conda without prompts
pwsh -ExecutionPolicy Bypass -File ".\PackageManagerInstaller.ps1" -PackageManagers @("conda") -Force -SkipConfirmation
```

## Configuration

The default configuration file is `config\settings.json`.

### Important behavior

- Package-manager settings belong in `PackageManagers`
- Installer defaults belong in `PackageManagerInstaller`
- File/Event Log settings belong in `Logging`
- Log retention belongs in `Advanced.logRetentionDays`
- Scheduling is configured through `Install-UPM.ps1`, not by editing `settings.json`

### Example

```json
{
  "Advanced": {
    "logRetentionDays": 30
  },
  "Logging": {
    "enableEventLog": true,
    "enableFileLog": true,
    "defaultLogLevel": "Info",
    "logRotation": "daily"
  },
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

## Logging

UPM supports file logging and Windows Event Log output.

- Log directory: `logs\`
- Daily log file: `UPM-YYYYMMDD.log`
- Event Log source: `UniversalPackageManager`
- Log levels: `Debug`, `Info`, `Warning`, `Error`, `Success`

Useful commands:

```powershell
# Tail the newest text log
Get-Content (Get-ChildItem ".\logs\UPM-*.log" | Sort-Object CreationTime | Select-Object -Last 1).FullName -Tail 50

# View recent Application log entries
Get-WinEvent -LogName Application -Source "UniversalPackageManager" -MaxEvents 20

# Check scheduled task status
Get-ScheduledTask -TaskName "Universal Package Manager" | Get-ScheduledTaskInfo
```

## Troubleshooting

### A package manager is not being updated

- Run `-Operation Status`
- Use `-DryRun -LogLevel Debug`
- Install or repair the package manager with `PackageManagerInstaller.ps1`

### Scheduled updates need a new time

Re-run `Install-UPM.ps1` with a new `-Frequency` or `-UpdateTime`.

### Scoop does not update from the scheduled task

That is expected. Scoop is user-scoped and is not available to the SYSTEM account by design.

### Conda or pip is not found in PATH

UPM already checks well-known system-wide install locations. If detection still fails, verify that the tool was installed system-wide.

## Architecture

UPM v3.0.2 is organized into:

- one orchestrator script
- three core modules for logging, configuration, and process execution
- one module per package manager

See:

- `USAGE.md` for operator-focused examples
- `MODULES.md` for module responsibilities and extension guidance
- `CONDA-RESEARCH-FINDINGS.md` for the Conda installation constraints and security background

## License

This project is provided as-is for educational and operational purposes.
