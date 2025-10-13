#Requires -Version 7.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    One-time migration script to rename scheduled task from versioned to version-agnostic name
.DESCRIPTION
    Renames the scheduled task from "Universal Package Manager v3.0" to "Universal Package Manager"
    to avoid version number conflicts in future updates. This is a breaking change cleanup script.
.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File ".\Migrate-TaskName.ps1"
.NOTES
    Version: 1.0
    Requires: Administrator privileges and PowerShell 7.0+
    Run this once after upgrading from v3.0.x to v3.0.2+
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Universal Package Manager - Task Name Migration (v3.0.2)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Old and new task names
$oldTaskName = "Universal Package Manager v3.0"
$newTaskName = "Universal Package Manager"

try {
    # Check if old task exists
    $oldTask = Get-ScheduledTask -TaskName $oldTaskName -ErrorAction SilentlyContinue
    
    if (-not $oldTask) {
        Write-Host "[INFO] Old task '$oldTaskName' not found." -ForegroundColor Yellow
        
        # Check if new task already exists
        $newTask = Get-ScheduledTask -TaskName $newTaskName -ErrorAction SilentlyContinue
        if ($newTask) {
            Write-Host "[SUCCESS] Task already migrated to '$newTaskName'" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "[WARNING] Neither old nor new task found. Run Install-UPM.ps1 to create it." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "[FOUND] Old task: $oldTaskName" -ForegroundColor White
    
    # Check if new task already exists (conflict)
    $newTask = Get-ScheduledTask -TaskName $newTaskName -ErrorAction SilentlyContinue
    if ($newTask) {
        Write-Host "[CONFLICT] Both old and new tasks exist!" -ForegroundColor Red
        Write-Host "  Removing old task: $oldTaskName" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false
        Write-Host "[SUCCESS] Old task removed. New task preserved." -ForegroundColor Green
        exit 0
    }
    
    # Export old task XML
    Write-Host "[EXPORT] Exporting task configuration..." -ForegroundColor White
    $taskXml = Export-ScheduledTask -TaskName $oldTaskName
    
    # Remove old task
    Write-Host "[REMOVE] Removing old task: $oldTaskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false
    
    # Import with new name
    Write-Host "[CREATE] Creating new task: $newTaskName" -ForegroundColor White
    Register-ScheduledTask -TaskName $newTaskName -Xml $taskXml -Force | Out-Null
    
    # Verify new task
    $verifyTask = Get-ScheduledTask -TaskName $newTaskName -ErrorAction Stop
    Write-Host ""
    Write-Host "[SUCCESS] Task migrated successfully!" -ForegroundColor Green
    Write-Host "  Old Name: $oldTaskName (removed)" -ForegroundColor Gray
    Write-Host "  New Name: $newTaskName (active)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  State: $($verifyTask.State)" -ForegroundColor White
    
    $trigger = $verifyTask.Triggers | Select-Object -First 1
    if ($trigger) {
        Write-Host "  Schedule: Daily at $($trigger.StartBoundary.ToString('HH:mm'))" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "[NEXT STEPS]" -ForegroundColor Cyan
    Write-Host "1. No further action needed - your scheduled updates will continue as configured" -ForegroundColor White
    Write-Host "2. Future reinstalls with Install-UPM.ps1 will use the version-agnostic name" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Migration failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure you're running as Administrator" -ForegroundColor White
    Write-Host "2. Check if Task Scheduler service is running" -ForegroundColor White
    Write-Host "3. Try manually removing the old task and running Install-UPM.ps1" -ForegroundColor White
    exit 1
}
