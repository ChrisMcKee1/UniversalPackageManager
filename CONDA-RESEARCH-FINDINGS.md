# Conda System-Wide Installation Research Findings

## Problem Statement
Initial attempt to install Miniconda system-wide to `C:\ProgramData\Miniconda3` failed silently. Installation directory was never created, despite script executing without errors.

## Root Cause: CVE-2022-26526 Security Fix

### The Vulnerability
**CVE-2022-26526** (Published: March 2022)
- **Severity**: 7.8 HIGH (CVSS 3.1)
- **Impact**: Local privilege escalation
- **Cause**: Anaconda/Miniconda could create world-writable directories in `%PROGRAMDATA%` and add them to system PATH, allowing local users to place Trojan horse files

**Reference**: https://nvd.nist.gov/vuln/detail/CVE-2022-26526

### The Fix (Breaking Change)
**As of Anaconda Distribution 2022.05 and Miniconda 4.12.0:**
- The `/AddToPath=1` parameter is **DISABLED** for AllUsers installations
- Combining `/InstallationType=AllUsers` with `/AddToPath=1` causes silent failure
- PATH must be manually configured after installation

**Official Documentation**: https://docs.conda.io/projects/conda/en/latest/user-guide/install/windows.html#installing-in-silent-mode

## Correct Installation Method

### Silent Install Syntax (Official)
```cmd
start /wait "" Miniconda3-latest-Windows-x86_64.exe /InstallationType=AllUsers /RegisterPython=0 /S /D=C:\ProgramData\Miniconda3
```

### Key Parameters
- `/InstallationType=AllUsers` - Install for all users (system-wide)
- `/RegisterPython=0` - Don't register as default Python (recommended if Python already installed)
- `/S` - Silent mode (suppress UI but allow error dialogs)
- `/D=<path>` - Destination path (MUST be last parameter, no quotes)
- **DO NOT USE**: `/AddToPath=1` - This is forbidden for AllUsers since 2022!

### Manual PATH Configuration (Required)
After successful installation, add these paths to Machine PATH:
1. `C:\ProgramData\Miniconda3`
2. `C:\ProgramData\Miniconda3\Scripts`
3. `C:\ProgramData\Miniconda3\Library\bin`

## What Was Wrong in Original Script

### ❌ Incorrect (Our Initial Attempt)
```powershell
$installArgs = @(
    "/InstallationType=AllUsers",
    "/RegisterPython=1",
    "/AddToPath=1",          # ← FORBIDDEN! Causes silent failure
    "/S",
    "/D=$installLocation"
)
Start-Process $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
```

**Problems:**
1. `/AddToPath=1` with AllUsers is rejected by installer (security policy)
2. `-NoNewWindow` hides error dialogs, making troubleshooting impossible
3. No exit code checking
4. No verification that installation actually occurred

### ✅ Correct (Fixed Version)
```powershell
$installArgs = @(
    "/InstallationType=AllUsers",
    "/RegisterPython=0",     # Don't conflict with existing Python
    "/S",
    "/D=$installLocation"    # Must be last
)
# REMOVED: /AddToPath=1

# Allow error dialogs to be visible
$process = Start-Process $installerPath -ArgumentList $installArgs -Wait -PassThru

# Check exit code
switch ($process.ExitCode) {
    0    { Write-Host "Success" }
    1602 { Write-Host "User cancelled"; exit 1602 }
    1618 { Write-Host "Another install running"; exit 1618 }
    1603 { Write-Host "Fatal error"; exit 1603 }
}

# Verify installation before declaring success
if (-not (Test-Path "$installLocation\Scripts\conda.exe")) {
    Write-Host "Installation failed - conda.exe not found"
    exit 1
}

# NOW manually add to Machine PATH
[Environment]::SetEnvironmentVariable("PATH", "$machinePath;$installLocation;$installLocation\Scripts;$installLocation\Library\bin", "Machine")
```

## Common MSI Exit Codes
- `0` - Success
- `1602` - User cancelled installation
- `1618` - Another installation is already in progress
- `1603` - Fatal error during installation
- `1619` - Installation package could not be opened

## Alternative: Chocolatey Installation
If direct installer continues to fail, use Chocolatey (already installed and working):

```powershell
choco install miniconda3 --params="/InstallationType:AllUsers" -y
```

**Advantages:**
- Chocolatey handles uninstall of existing versions
- Proper parameter handling
- Better error reporting
- Automatic PATH configuration
- Proven to work in enterprise environments

## Verification Steps

After installation:

```powershell
# 1. Check installation directory
Test-Path "C:\ProgramData\Miniconda3\Scripts\conda.exe"

# 2. Check Machine PATH contains conda
[Environment]::GetEnvironmentVariable("PATH", "Machine") -split ';' | Where-Object { $_ -like "*Miniconda*" }

# 3. Refresh PATH and test command
$env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
Get-Command conda  # Should show C:\ProgramData\Miniconda3\Scripts\conda.exe

# 4. Test in SYSTEM context (scheduled task)
Start-ScheduledTask -TaskName "Universal Package Manager"
Start-Sleep 10
Get-Content "C:\ProgramData\UniversalPackageManager\logs\UPM-*.log" | Select-Object -Last 30
```

**Success Criteria:**
- ✅ `C:\ProgramData\Miniconda3\Scripts\conda.exe` exists
- ✅ Machine PATH contains `C:\ProgramData\Miniconda3\Scripts`
- ✅ `Get-Command conda` shows system-wide location (not user-scoped)
- ✅ Scheduled task log shows: "Conda: Found at C:\ProgramData\Miniconda3\Scripts\conda.exe"

## Key Learnings

1. **Security patches can introduce breaking changes** - What worked in 2021 may not work in 2025
2. **Always research official documentation** - Enterprise/system-wide installations often have special requirements
3. **Silent installs can hide critical errors** - Allow error dialogs during troubleshooting
4. **Verify installation actually occurred** - Check for files before declaring success
5. **Exit codes matter** - Capture and interpret them properly
6. **PATH configuration is manual** - For AllUsers Conda installations since 2022

## Timeline of Changes

- **Pre-2022**: `/AddToPath=1` worked with `/InstallationType=AllUsers`
- **March 2022**: CVE-2022-26526 discovered and disclosed
- **April 2022**: Anaconda 2022.05 released with security fix
- **April 2022**: Miniconda 4.12.0 released with security fix
- **October 2025**: We discovered this while troubleshooting UPM v3.0

## References

1. Official Documentation: https://docs.conda.io/projects/conda/en/latest/user-guide/install/windows.html
2. CVE Details: https://nvd.nist.gov/vuln/detail/CVE-2022-26526
3. Miniconda Downloads: https://docs.anaconda.com/miniconda/
4. GitHub Issues: https://github.com/conda/conda/issues
5. Anaconda Issues: https://github.com/ContinuumIO/anaconda-issues/issues

---

**Updated**: October 13, 2025  
**Author**: UPM v3.0 Development Team  
**Status**: Fixed in Install-CondaSystemWide.ps1 v2.0
