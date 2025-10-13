# Universal Package Manager - AI Coding Agent Instructions

## Project Context
UPM v3.0 is a **PowerShell 7+ exclusive** automation system that orchestrates package updates across 6 Windows package managers (winget, Chocolatey, Scoop, npm, pip, Conda) using a modular architecture. It runs as a scheduled task with SYSTEM privileges.

**Current Status (v3.0.2):**
- ✅ **5/6 package managers working** in SYSTEM context (Chocolatey, Winget, NPM, Pip, Conda)
- ✅ **System-wide installations** with `--scope machine` flag
- ✅ **Well-known path fallbacks** for finding package managers not in PATH
- ✅ **Conda working** after fixing CVE-2022-26526 security issue
- ⚠️ **Scoop user-only** by design (cannot work in SYSTEM context)

## Architecture Overview

### Modular Design Pattern
- **Core orchestrator**: `UniversalPackageManager.ps1` - imports modules, maps package manager functions, coordinates execution
- **Core modules** (in `modules/`):
  - `UPM.Logging.psm1` - Structured JSON + console logging with Windows Event Log integration
  - `UPM.Configuration.psm1` - JSON config management with validation
  - `UPM.ProcessExecution.psm1` - PowerShell 7+ native timeout handling with retry logic, **npm.cmd fix** for proper command resolution
- **Package manager modules**: `UPM.PackageManager.<Name>.psm1` - Each implements standardized interface: `Test-Available`, `Update-Packages`, `Get-Info`
  - **Well-known path fallbacks** - Searches system-wide locations when commands not in PATH

### Key Design Decisions
- **PowerShell 7+ only**: Uses `#Requires -Version 7.0`, native `TimeoutSec` parameter, `$PSStyle` for colors
- **Clean reinstalls**: `Install-UPM.ps1` always removes old tasks before creating new ones
- **SYSTEM privileges**: Scheduled task runs as `NT AUTHORITY\SYSTEM` with highest privileges
- **System-wide installations**: All package managers (except Scoop) installed to Program Files or ProgramData for SYSTEM access
- **Daily log rotation**: One file per day (v3.0.1+), not per execution

## Critical Workflows

### Installation & Setup
```powershell
# Standard installation (creates scheduled task)
pwsh -ExecutionPolicy Bypass -File "C:\ProgramData\UniversalPackageManager\Install-UPM.ps1"

# Install missing package managers (auto-accepts by default, installs system-wide)
pwsh -ExecutionPolicy Bypass -File ".\PackageManagerInstaller.ps1"
```

**System-Wide Installation Strategy:**
- All package managers installed with `--scope machine` for system-wide availability
- Node.js, Python, Conda: Installed to Program Files via winget machine scope
- Chocolatey: Already system-wide (C:\ProgramData\chocolatey)
- Scoop: User-scoped by design (fallback paths supported)
- This ensures scheduled task running as NT AUTHORITY\SYSTEM can access all tools

### Manual Testing
```powershell
# Dry-run with debug output (use this for testing changes)
pwsh -File ".\UniversalPackageManager.ps1" -DryRun -LogLevel Debug

# Test specific package manager
pwsh -File ".\UniversalPackageManager.ps1" -SelectedPackageManagers @("winget") -DryRun
```

### Module Development Pattern
When creating/modifying package manager modules:
1. Import dependencies: `using module ./UPM.Logging.psm1` and `using module ./UPM.ProcessExecution.psm1`
2. Implement required functions: `Test-<PM>Available`, `Update-<PM>Packages`, `Get-<PM>Info`
3. Use `Write-UPMLog` with `-Component` parameter (e.g., "WINGET", "CHOCO")
4. Use `Invoke-UPMProcess` for all external commands with timeout handling
5. Return structured hashtables with `Success`, `Duration`, `ExitCode` keys

## Configuration Management

### settings.json Structure
- **DO NOT** configure scheduling here - use `Install-UPM.ps1` parameters (`-UpdateTime`, `-Frequency`)
- **DO** configure per-package-manager: `enabled`, `timeout`, `args`
- **Logging section** (v3.0.1+): Controls Event Log (`enableEventLog`) and file logging (`enableFileLog`)
- **Only `logRetentionDays`** is used from `Advanced` section

Example modification:
```powershell
# Disable Chocolatey, extend winget timeout
$config = Get-Content "config\settings.json" | ConvertFrom-Json
$config.PackageManagers.choco.enabled = $false
$config.PackageManagers.winget.timeout = 1200
$config | ConvertTo-Json -Depth 10 | Set-Content "config\settings.json"
```

## Package Manager Function Mapping
In `UniversalPackageManager.ps1`, the `$script:PackageManagerFunctions` hashtable maps short names to module functions:
```powershell
"winget" -> Test-WingetAvailable, Update-WingetPackages, Get-WingetInfo
"choco"  -> Test-ChocolateyAvailable, Update-ChocolateyPackages, Get-ChocolateyInfo
# ...etc for scoop, npm, pip, conda
```

## Logging Conventions
- Use **component names** consistently: "MAIN", "CONFIG", "WINGET", "CHOCO", "SCOOP", "NPM", "PIP", "CONDA"
- Log levels: `Debug` (detailed), `Info` (progress), `Warning` (non-fatal issues), `Error` (failures), `Success` (completions)
- Include structured data with `-Data` parameter: `@{ "Duration" = $elapsed; "ExitCode" = $code }`
- Windows Event Log integration: Critical events logged to Application log with source "UniversalPackageManager"

## Breaking Changes in v3.0
- Removed Windows PowerShell 5.1 support (was monolithic `UniversalPackageManager-old.ps1`)
- Scheduled task name changed to "Universal Package Manager" (version-agnostic as of v3.0.2)
- Configuration schema updated (added `Logging` section in v3.0.1)
- All scripts require `#Requires -RunAsAdministrator` for privilege elevation

## Testing & Debugging
```powershell
# Check scheduled task status
Get-ScheduledTask -TaskName "Universal Package Manager" | Get-ScheduledTaskInfo

# View recent logs (file-based)
Get-Content (Get-ChildItem "logs\UPM-*.log" | Sort-Object CreationTime | Select-Object -Last 1).FullName -Tail 50

# View Event Log entries
Get-WinEvent -LogName Application -Source "UniversalPackageManager" -MaxEvents 20
```

## Common Pitfalls
1. **Don't use emoji/Unicode** - Removed in v3.0 for Windows PowerShell compatibility
2. **Module size**: Keep modules ~50-80 lines; split if growing beyond 100 lines
3. **Timeout handling**: Always use `Invoke-UPMProcess` with explicit `-TimeoutSeconds`, not raw `Start-Process`
4. **Configuration**: Remember scheduling is in scheduled task, NOT settings.json
5. **Module imports**: Use absolute paths with `Join-Path $script:ModulesDir` pattern
6. **npm.cmd vs npm.ps1**: Test-UPMCommand has special handling for npm to find `.cmd` files before `.ps1` scripts
7. **Conda security**: Never use `/AddToPath=1` with `/InstallationType=AllUsers` (CVE-2022-26526) - configure PATH manually

## Key Fixes & Improvements (v3.0.2)

### NPM Detection Fix
**Problem**: npm.ps1 selected instead of npm.cmd causing "not a valid Win32 application" error  
**Solution**: `Test-UPMCommand` in `UPM.ProcessExecution.psm1` has special npm handling that searches only .cmd/.bat extensions  
**Location**: Lines 183-217 of `UPM.ProcessExecution.psm1`

### Conda System-Wide Installation
**Problem**: `/AddToPath=1` parameter forbidden for AllUsers installations since Miniconda 4.12.0 (CVE-2022-26526)  
**Solution**: Install without `/AddToPath=1`, manually configure Machine PATH afterward  
**Research**: See `CONDA-RESEARCH-FINDINGS.md` for complete CVE analysis  
**Reference**: https://docs.conda.io/projects/conda/en/latest/user-guide/install/windows.html

### Well-Known Path Fallbacks
**Problem**: Package managers not in PATH when running as SYSTEM  
**Solution**: Modules search system-wide locations:
- Winget: `C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller*\winget.exe`
- Pip: `C:\Program Files\Python3*\Scripts\pip.exe`
- Conda: `C:\ProgramData\Miniconda3\Scripts\conda.exe` (prioritized over user locations)
**Modules**: Winget, Pip, and Conda modules implement this pattern

### System-Wide Installation Strategy
**Implementation**: `PackageManagerInstaller.ps1` uses `--scope machine` flag for winget installs (lines 892, 970, 1067)  
**Result**: Node.js, Python installed to `C:\Program Files` instead of user AppData  
**Benefit**: Accessible to NT AUTHORITY\SYSTEM account for scheduled tasks

## Package Manager Status

| Package Manager | Status | Path | Notes |
|----------------|--------|------|-------|
| **Chocolatey** | ✅ Working | `C:\ProgramData\chocolatey\bin\choco.exe` | System-wide by design |
| **Winget** | ✅ Working | Well-known paths in WindowsApps | Fallback implemented |
| **NPM** | ✅ Working | `C:\Program Files\nodejs\npm.cmd` | npm.cmd fix applied |
| **Pip** | ✅ Working | `C:\Program Files\Python313\Scripts\pip.exe` | Machine PATH + fallback |
| **Conda** | ✅ Working | `C:\ProgramData\Miniconda3\Scripts\conda.exe` | CVE fix + fallback paths |
| **Scoop** | ⚠️ User-only | `C:\Users\<user>\scoop\shims\scoop.ps1` | By design, cannot be system-wide |

**Coverage**: 5/6 working in SYSTEM context (83%)
