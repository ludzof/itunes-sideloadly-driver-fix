#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fixes the rogue Apple USB driver 538.0.0.0 issue on Windows 10/11 for iTunes, Sideloadly, AltStore, and 3uTools.
.DESCRIPTION
    Windows Update often forces driver version 538.0.0.0 (appleusb.inf), which breaks USB composite communication,
    causing LOCKDOWN_E_MUX_ERROR, iTunes error 0xE8000065, or device disconnection loops.
    This script removes the bad driver from the Driver Store, cleans the device tree, re-installs the official
    usbaapl64.inf driver, and configures Windows Update policies to prevent re-infection.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Apple USB Driver Fixer"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "     Apple USB Driver Fixer for iTunes & Sideloadly     " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[-] ERROR: This script requires administrative privileges." -ForegroundColor Red
    Write-Host "    Please run this script or Fix-Apple-Driver.bat as Administrator." -ForegroundColor Yellow
    exit 1
}

# 2. Search and Delete Rogue 538.0.0.0 Drivers
Write-Host "[*] Step 1: Searching for rogue Apple driver 538.0.0.0 in Driver Store..." -ForegroundColor Yellow
$driverList = pnputil /enum-drivers
$currentOem = ""
$foundOems = @()

foreach ($line in ($driverList -split "`r?`n")) {
    if ($line -match "Published Name:\s+(oem\d+\.inf)") {
        $currentOem = $matches[1]
    }
    if ($line -match "Driver Version:\s+.*538\.0\.0\.0") {
        if ($currentOem -and -not ($foundOems -contains $currentOem)) {
            $foundOems += $currentOem
        }
    }
}

if ($foundOems.Count -gt 0) {
    foreach ($oem in $foundOems) {
        Write-Host "    [-] Removing rogue driver package: $oem (538.0.0.0)..." -ForegroundColor Yellow
        $deleteResult = & pnputil /delete-driver $oem /uninstall /force 2>&1
        Write-Host "        $deleteResult" -ForegroundColor Gray
    }
    Write-Host "[+] Rogue driver(s) successfully uninstalled." -ForegroundColor Green
} else {
    Write-Host "[i] No 538.0.0.0 drivers found in Driver Store." -ForegroundColor Green
}

# 3. Clean Apple Devices from PnP Hardware Tree
Write-Host ""
Write-Host "[*] Step 2: Clearing cached Apple USB device tree..." -ForegroundColor Yellow
try {
    $appleDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { 
        $_.FriendlyName -match 'Apple' -or $_.InstanceId -match 'VID_05AC' 
    }
    if ($appleDevices) {
        foreach ($dev in $appleDevices) {
            Write-Host "    [-] Removing device instance: $($dev.FriendlyName) ($($dev.InstanceId))..." -ForegroundColor Gray
            & pnputil /remove-device $dev.InstanceId /subtree 2>&1 | Out-Null
        }
    }
    Write-Host "[+] Apple device instances cleared from tree." -ForegroundColor Green
} catch {
    Write-Host "[!] Warning: Could not enumerate all PnP devices: $_" -ForegroundColor Yellow
}

# 4. Locate and Reinstall Official Apple Driver (usbaapl64.inf / usbaapl.inf)
Write-Host ""
Write-Host "[*] Step 3: Locating official Apple Mobile Device Support driver..." -ForegroundColor Yellow
$driverCandidates = @(
    "C:\Program Files\Common Files\Apple\Mobile Device Support\Drivers\usbaapl64.inf",
    "C:\Program Files (x86)\Common Files\Apple\Mobile Device Support\Drivers\usbaapl64.inf",
    "C:\Program Files\Common Files\Apple\Mobile Device Support\Drivers\usbaapl.inf",
    "C:\Program Files (x86)\Common Files\Apple\Mobile Device Support\Drivers\usbaapl.inf"
)

$targetDriver = $null
foreach ($path in $driverCandidates) {
    if (Test-Path -Path $path) {
        $targetDriver = $path
        break
    }
}

if ($targetDriver) {
    Write-Host "    Found official driver: $targetDriver" -ForegroundColor Gray
    Write-Host "    [+] Installing official driver into driver store..." -ForegroundColor Yellow
    $installResult = & pnputil /add-driver $targetDriver /install 2>&1
    Write-Host "        $($installResult -join "`n        ")" -ForegroundColor Gray
    Write-Host "[+] Official Apple driver installed." -ForegroundColor Green
} else {
    Write-Host "[!] WARNING: Could not find usbaapl64.inf." -ForegroundColor Red
    Write-Host "    Please ensure iTunes (standalone installer) or Apple Mobile Device Support is installed." -ForegroundColor Yellow
}

# 5. Hardware Rescan
Write-Host ""
Write-Host "[*] Step 4: Rescanning hardware for changes..." -ForegroundColor Yellow
& pnputil /scan-devices | Out-Null
Write-Host "[+] Hardware scan complete." -ForegroundColor Green

# 6. Restart Apple Mobile Device Service (AMDS)
Write-Host ""
Write-Host "[*] Step 5: Restarting Apple Mobile Device Service..." -ForegroundColor Yellow
$service = Get-Service -Name "Apple Mobile Device Service" -ErrorAction SilentlyContinue
if ($service) {
    Restart-Service -Name "Apple Mobile Device Service" -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Apple Mobile Device Service restarted successfully." -ForegroundColor Green
} else {
    Write-Host "[i] Apple Mobile Device Service is not currently installed or registered." -ForegroundColor Yellow
}

# 7. Apply Registry Policies to Block Windows Update from Reinstalling Drivers
Write-Host ""
Write-Host "[*] Step 6: Applying registry protections against Windows Update driver overrides..." -ForegroundColor Yellow
try {
    # Exclude drivers from quality updates
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (-not (Test-Path $wuPath)) {
        New-Item -Path $wuPath -Force | Out-Null
    }
    Set-ItemProperty -Path $wuPath -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -Force

    # Disable automatic driver search/replacement
    $dsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
    if (Test-Path $dsPath) {
        Set-ItemProperty -Path $dsPath -Name "SearchOrderConfig" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[+] Windows Update driver override prevention applied." -ForegroundColor Green
} catch {
    Write-Host "[!] Could not set registry policy: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "                       ALL DONE!                        " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host " 1. Unplug your iPhone / iPad from the USB cable."
Write-Host " 2. (Optional) If prompted by Windows that a reboot is pending, restart your PC."
Write-Host " 3. Reconnect your iPhone, unlock the screen, and tap 'Trust This Computer'."
Write-Host " 4. Open iTunes or Sideloadly. Your device should now be recognized!"
Write-Host ""
