<#
.SYNOPSIS
    Read-only diagnostic script to check the status of Apple USB drivers and devices on Windows.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "         Apple USB Driver Status Diagnostics            " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[*] Checking Apple PnP Devices..." -ForegroundColor Yellow

$appleDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { 
    $_.FriendlyName -match 'Apple' -or $_.InstanceId -match 'VID_05AC' 
}

if ($appleDevices) {
    foreach ($dev in $appleDevices) {
        $driverVer = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction SilentlyContinue).Data
        $statusColor = if ($dev.Status -eq 'OK') { "Green" } else { "Red" }
        $verColor = if ($driverVer -match '538\.0\.0\.0') { "Red" } elseif ($driverVer -match '6\.0\.') { "Green" } else { "Yellow" }
        
        Write-Host "Device: $($dev.FriendlyName)" -ForegroundColor White
        Write-Host "  - Class: $($dev.Class)" -ForegroundColor Gray
        Write-Host "  - Status: " -NoNewline
        Write-Host "$($dev.Status)" -ForegroundColor $statusColor
        Write-Host "  - Driver Version: " -NoNewline
        Write-Host "$($driverVer)" -ForegroundColor $verColor
        Write-Host "  - Instance ID: $($dev.InstanceId)" -ForegroundColor DarkGray
        Write-Host ""
    }
} else {
    Write-Host "[i] No connected Apple devices detected." -ForegroundColor Yellow
}

Write-Host "[*] Checking Apple drivers in Driver Store (pnputil)..." -ForegroundColor Yellow
$drivers = pnputil /enum-drivers
$currentOem = ""
$found538 = $false

foreach ($line in ($drivers -split "`r?`n")) {
    if ($line -match "Published Name:\s+(oem\d+\.inf)") {
        $currentOem = $matches[1]
    }
    if ($line -match "Driver Version:\s+.*538\.0\.0\.0") {
        Write-Host "  [!] Rogue driver 538.0.0.0 found in $currentOem!" -ForegroundColor Red
        $found538 = $true
    }
    if ($line -match "Driver Version:\s+.*6\.0\.9999\.69") {
        Write-Host "  [+] Official driver 6.0.9999.69 found in $currentOem." -ForegroundColor Green
    }
}

if (-not $found538) {
    Write-Host "  [+] No rogue 538.0.0.0 driver in the Driver Store." -ForegroundColor Green
}

Write-Host ""
Write-Host "[*] Checking Apple Mobile Device Service..." -ForegroundColor Yellow
$amds = Get-Service -Name "Apple Mobile Device Service" -ErrorAction SilentlyContinue
if ($amds) {
    $svcColor = if ($amds.Status -eq 'Running') { "Green" } else { "Red" }
    Write-Host "  Service Status: " -NoNewline
    Write-Host "$($amds.Status)" -ForegroundColor $svcColor
} else {
    Write-Host "  [!] Service not found (iTunes may need to be reinstalled)." -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
