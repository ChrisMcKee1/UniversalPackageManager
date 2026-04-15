# Universal Package Manager module guide

UPM v3.0.2 uses a modular PowerShell 7+ architecture. The main script coordinates execution, while each module owns one area of behavior.

## High-level structure

```text
UniversalPackageManager.ps1
├── UPM.Logging.psm1
├── UPM.Configuration.psm1
├── UPM.ProcessExecution.psm1
├── UPM.PackageManager.Winget.psm1
├── UPM.PackageManager.Chocolatey.psm1
├── UPM.PackageManager.Scoop.psm1
├── UPM.PackageManager.Npm.psm1
├── UPM.PackageManager.Pip.psm1
└── UPM.PackageManager.Conda.psm1
```

## Orchestrator

### `UniversalPackageManager.ps1`

Responsibilities:

- imports all core and package manager modules
- maps each package manager name to its `Test`, `Update`, and `Info` functions
- initializes logging and configuration
- runs one of three operations: `Update`, `Status`, or `Configure`

Supported package manager keys:

- `winget`
- `choco`
- `scoop`
- `npm`
- `pip`
- `conda`

## Core modules

### `UPM.Logging.psm1`

Handles:

- console logging
- Windows Event Log initialization
- daily file log creation (`UPM-YYYYMMDD.log`)
- retention cleanup through `Remove-OldLogFiles`
- operation timing helpers

Key exported functions:

- `Initialize-UPMLogging`
- `Write-UPMLog`
- `Start-UPMTimer`
- `Stop-UPMTimer`
- `Remove-OldLogFiles`

### `UPM.Configuration.psm1`

Handles:

- loading `settings.json`
- merging defaults with on-disk settings
- validating configuration structure
- returning enabled package managers
- updating persisted settings

Notable configuration sections:

- `Advanced`
- `Logging`
- `Service`
- `UI`
- `PackageManagers`
- `PackageManagerInstaller`

### `UPM.ProcessExecution.psm1`

Handles:

- process execution with timeout support
- retry logic for external commands
- command discovery
- npm-specific `.cmd` lookup to avoid incorrect PowerShell script selection

Use this module for all external command execution instead of calling tools directly from modules.

## Package manager modules

Each package manager module exposes the same primary interface:

- `Test-<Name>Available`
- `Update-<Name>Packages`
- `Get-<Name>Info`

### `UPM.PackageManager.Winget.psm1`

- Manages winget updates
- Includes well-known WindowsApps path fallbacks
- Also exports:
  - `Get-WingetPackages`
  - `Get-WingetUpgradablePackages`

### `UPM.PackageManager.Chocolatey.psm1`

- Manages Chocolatey updates
- Also exports:
  - `Get-ChocolateyPackages`
  - `Get-ChocolateyUpgradablePackages`
  - `Update-ChocolateyItself`

### `UPM.PackageManager.Scoop.psm1`

- Manages Scoop updates
- Intended for user-scoped installs

### `UPM.PackageManager.Npm.psm1`

- Manages global npm package updates
- Relies on `npm.cmd` resolution from the process-execution module

### `UPM.PackageManager.Pip.psm1`

- Manages pip package updates
- Searches common system-wide Python installation paths when PATH lookup fails

### `UPM.PackageManager.Conda.psm1`

- Manages Conda package updates
- Prefers system-wide install locations for SYSTEM-context compatibility
- Avoids depending on unsupported AllUsers `/AddToPath=1` installation behavior

## Extension pattern

To add another package manager module:

1. Create a new `UPM.PackageManager.<Name>.psm1` file
2. Implement `Test`, `Update`, and `Info` functions following the existing naming convention
3. Use `Write-UPMLog` for logging
4. Use `Invoke-UPMProcess` for external commands
5. Import the module in `UniversalPackageManager.ps1`
6. Add the package manager to the orchestrator function map
7. Add matching configuration in `config/settings.json`

## Operational design notes

- PowerShell 7+ is required throughout the project
- The scheduled task runs as `SYSTEM` with highest privileges
- Most package managers are expected to be installed machine-wide
- Scoop remains the exception because it is user-scoped by design
- Logging is daily, not per execution
