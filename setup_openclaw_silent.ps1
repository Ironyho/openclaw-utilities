# OpenClaw Gateway Silent Startup Configuration Script
# Run as Administrator

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "OpenClaw Gateway Silent Startup Config" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Ensure directory
$openclawDir = Join-Path $env:USERPROFILE ".openclaw"
Write-Host "`nStep 1: Ensure directory $openclawDir" -ForegroundColor Yellow

try {
    if (-not (Test-Path $openclawDir)) {
        New-Item -ItemType Directory -Path $openclawDir -Force | Out-Null
        Write-Host "OK: Directory created" -ForegroundColor Green
    } else {
        Write-Host "OK: Directory exists" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to create directory: $_"
    exit 1
}

# Step 2: Create gateway_start.vbs file
$vbsPath = Join-Path $openclawDir "gateway_start.vbs"
Write-Host "`nStep 2: Create VBS file: $vbsPath" -ForegroundColor Yellow

# Build VBS content line by line to avoid here-string issues
$vbsLines = @(
    'Set WshShell = CreateObject("WScript.Shell")',
    'userProfile = WshShell.ExpandEnvironmentStrings("%USERPROFILE%")',
    'WshShell.Run userProfile + "\.openclaw\gateway.cmd", 0, False',
    'Set WshShell = Nothing'
)

$vbsContent = $vbsLines -join "`r`n"

try {
    # Use ASCII encoding to avoid encoding issues
    [System.IO.File]::WriteAllText($vbsPath, $vbsContent, [System.Text.Encoding]::ASCII)
    Write-Host "OK: VBS file created" -ForegroundColor Green
    Write-Host "Content:" -ForegroundColor Gray
    $vbsLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} catch {
    Write-Error "Failed to create VBS file: $_"
    exit 1
}

# Step 3: Find and modify scheduled task
Write-Host "`nStep 3: Find OpenClaw Gateway scheduled task" -ForegroundColor Yellow

$foundTasks = Get-ScheduledTask | Where-Object { 
    $_.TaskName -match "OpenClaw" -or 
    $_.TaskName -match "openclaw" -or
    ($_.Description -and ($_.Description -match "OpenClaw" -or $_.Description -match "openclaw"))
}

if (-not $foundTasks) {
    Write-Warning "No OpenClaw scheduled task found"
    Write-Host "`nPlease manually check Task Scheduler (taskschd.msc)" -ForegroundColor Cyan
    Write-Host "Then change the action to:" -ForegroundColor Yellow
    Write-Host $vbsPath -ForegroundColor White
    exit 0
}

Write-Host "-- Found $($foundTasks.Count) task(s):" -ForegroundColor Green
$foundTasks | ForEach-Object { 
    Write-Host "  - [$($_.State)] $($_.TaskPath)$($_.TaskName)" -ForegroundColor White 
}

# Select target task (prefer one with "Gateway" in name)
$targetTask = $foundTasks | Where-Object { $_.TaskName -match "Gateway" } | Select-Object -First 1
if (-not $targetTask) {
    $targetTask = $foundTasks | Select-Object -First 1
}

if (-not $targetTask) {
    Write-Error "Failed to select a valid task"
    exit 1
}

$fullTaskName = $targetTask.TaskPath + $targetTask.TaskName
Write-Host "`n-- Modifying task: $fullTaskName" -ForegroundColor Yellow

try {
    $taskDetail = Get-ScheduledTask -TaskName $targetTask.TaskName -TaskPath $targetTask.TaskPath
    $currentAction = $taskDetail.Actions[0]

    Write-Host "Current config:" -ForegroundColor Gray
    Write-Host "  Program: $($currentAction.Execute)" -ForegroundColor Gray
    if ($currentAction.Arguments) {
        Write-Host "  Arguments: $($currentAction.Arguments)" -ForegroundColor Gray
    }

    # Create new action
    $newAction = New-ScheduledTaskAction -Execute $vbsPath

    # Update task with new action
    Write-Host "`nUpdating task..." -ForegroundColor Yellow
    Set-ScheduledTask -TaskName $targetTask.TaskName -TaskPath $targetTask.TaskPath -Action $newAction | Out-Null

    Write-Host "OK: Task updated successfully" -ForegroundColor Green
    Write-Host "  New program: $vbsPath" -ForegroundColor Green

} catch {
    Write-Error "Failed to modify task: $_"
    Write-Host "`nPlease manually modify:" -ForegroundColor Cyan
    Write-Host "1. Run taskschd.msc" -ForegroundColor White
    Write-Host "2. Find task: $($targetTask.TaskName)" -ForegroundColor White
    Write-Host "3. Right-click -> Properties -> Actions -> Edit" -ForegroundColor White
    Write-Host "4. Change Program to: $vbsPath" -ForegroundColor Yellow
    Write-Host "5. Clear Arguments and Start in fields" -ForegroundColor White
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Startup Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VBS file: $vbsPath" -ForegroundColor White
Write-Host "`nOpenClaw Gateway will start silently on next boot" -ForegroundColor Green

# Step 4: Stop existing gateway PowerShell/CMD process
Write-Host "`nStep 4: Stop existing gateway process" -ForegroundColor Yellow

$gatewayProcs = Get-CimInstance Win32_Process |
    Where-Object { $_.Name -match "^(node|openclaw-gateway)\.exe$" } |
    Where-Object { $_.Name -eq "openclaw-gateway.exe" -or $_.CommandLine -match "gateway" }

if ($gatewayProcs) {
    $gatewayProcs | ForEach-Object {
        Write-Host "  Stopping PID $($_.ProcessId): $($_.CommandLine)" -ForegroundColor Gray
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "OK: Gateway process(es) stopped" -ForegroundColor Green
} else {
    Write-Host "No running gateway process found, skipping" -ForegroundColor Gray
}

# Step 5: Launch VBS once to start the gateway
Write-Host "`nStep 5: Launch gateway now" -ForegroundColor Yellow

try {
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`""
    Write-Host "OK: Gateway launched" -ForegroundColor Green
    Start-Sleep -Seconds 1
} catch {
    Write-Error "Failed to launch gateway: $_"
    exit 1
}

# Step 6: Prompt user about completion
Write-Host "`nStep 6: All Completed" -ForegroundColor Yellow

$message = "OpenClaw configuration completed. Please visit your browser to experience it!`n"
Write-Host $message -ForegroundColor Green