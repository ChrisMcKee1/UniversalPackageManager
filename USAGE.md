# Universal Package Manager usage

This guide focuses on day-to-day operation of UPM after the files are in place.

## Main script

The main entry point is:

```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1"
```

### Parameters

| Parameter | Purpose | Values |
| --- | --- | --- |
| `-Operation` | Select the workflow to run | `Update`, `Status`, `Configure` |
| `-SelectedPackageManagers` | Limit execution to specific package managers | `winget`, `choco`, `scoop`, `npm`, `pip`, `conda` |
| `-DryRun` | Preview changes without applying updates | switch |
| `-LogLevel` | Control verbosity | `Debug`, `Info`, `Warning`, `Error` |
| `-Silent` | Reduce console output | switch |
| `-ConfigPath` | Use an alternate configuration file | file path |

## Common operations

### Update all enabled package managers

```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1"
```

### Dry run

```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -DryRun
```

### Debug a specific package manager

```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -SelectedPackageManagers @("conda") -DryRun -LogLevel Debug
```

### Check status

```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Status
```

### Open the configuration file in the default editor

```powershell
pwsh -File "C:\ProgramData\UniversalPackageManager\UniversalPackageManager.ps1" -Operation Configure
```

## Scheduled task installation

Create or recreate the scheduled task:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"
```

Create a weekly schedule on Sunday at 03:30:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1" -Frequency Weekly -UpdateTime "03:30"
```

The installer creates a task named `Universal Package Manager` that runs as `SYSTEM` with highest privileges.

## Package manager installation

Install or upgrade all supported package managers:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1"
```

Install only selected targets:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1" -PackageManagers @("choco", "conda")
```

Force reinstall without prompts:

```powershell
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\PackageManagerInstaller.ps1" -Force -SkipConfirmation
```

Valid installer targets are `winget`, `choco`, `scoop`, `nodejs`, `python`, `conda`, and `all`.

## Logging and diagnostics

### Read the newest file log

```powershell
Get-Content (Get-ChildItem "C:\ProgramData\UniversalPackageManager\logs\UPM-*.log" | Sort-Object CreationTime | Select-Object -Last 1).FullName -Tail 50
```

### Check Windows Event Log entries

```powershell
Get-WinEvent -LogName Application -Source "UniversalPackageManager" -MaxEvents 20
```

### Inspect the scheduled task

```powershell
Get-ScheduledTask -TaskName "Universal Package Manager" | Get-ScheduledTaskInfo
```

## Notes

- Scoop is user-scoped and is not expected to work from the SYSTEM scheduled task
- npm detection intentionally prefers `npm.cmd`
- pip, Conda, and winget include well-known path fallbacks for SYSTEM-context execution
- Log rotation is daily and retention is controlled by `Advanced.logRetentionDays`
