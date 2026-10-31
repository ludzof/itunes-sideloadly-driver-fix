# Apple USB Driver Fixer for Windows

> **Fix for `LOCKDOWN_E_MUX_ERROR`, iTunes Error `0xE8000065`, and iPhone not being detected in iTunes, Sideloadly, AltStore, SideStore, and 3uTools.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows 10 / 11](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue.svg)](https://microsoft.com/windows)
[![Tested on: iTunes & Sideloadly](https://img.shields.io/badge/Compatibility-iTunes%20%7C%20Sideloadly%20%7C%20AltStore-success.svg)](https://sideloadly.io)

---

## The Problem

On Windows 10 and Windows 11, users attempting to connect an iPhone or iPad to **iTunes**, **Sideloadly**, **AltStore**, or other sideloading utilities frequently encounter stubborn connection failures:

- **Sideloadly / AltStore:** Fails with `Call to lockdownd_client_new_with_handshake failed: LOCKDOWN_E_MUX_ERROR`.
- **iTunes:** Shows an alert `iTunes could not connect to this iPhone. An unknown error occurred (0xE8000065)`.
- **Disconnection Loop:** The iPhone appears in iTunes or File Explorer for 1–2 seconds and then immediately vanishes.
- **Device Manager:** Shows `Apple Mobile Device USB Composite Device` or `Apple Mobile Device USB Device` with a yellow triangle or "Unknown" status.

### Root Cause

Windows Update (and third-party driver updaters) silently downloads an optional/mandatory driver package named **`Apple, Inc. - Universal Serial Bus devices`** version **`538.0.0.0`** (`appleusb.inf`).

While this driver may sound newer, it **breaks composite USB multiplexing (`usbmuxd`)** needed by Apple Mobile Device Support (AMDS). Desktop applications like iTunes and Sideloadly require the official Apple desktop driver **`6.0.9999.69`** (`usbaapl64.inf`).

Even worse: Windows Update regularly reinstalls `538.0.0.0` in the background after major cumulative patches unless specific Group Policy restrictions are applied.

---

## What This Tool Does

1. **Purges Rogue Drivers:** Scans the Windows Driver Store (`pnputil /enum-drivers`) and forcefully deletes any installed driver packages matching version `538.0.0.0`.
2. **Cleans Device Tree:** Removes stuck or corrupted Apple PnP device nodes from the hardware tree so Windows stops holding onto cached broken driver instances in RAM.
3. **Reinstalls Official Driver:** Automatically locates the official Apple Mobile Device Support driver (`usbaapl64.inf`) and binds it back to your device.
4. **Restarts Background Services:** Restarts `Apple Mobile Device Service` (AMDS) to cleanly re-establish communication.
5. **Prevents Re-infection:** Sets Windows Update registry policies (`ExcludeWUDriversInQualityUpdate = 1` and `SearchOrderConfig = 0`) to prevent Windows from silently overwriting the driver again.

---

## Quick Start (1-Click Fix)

### Option 1: Run the Batch File (Easiest)

1. Download or clone this repository.
2. Right-click **`Fix-Apple-Driver.bat`** and select **Run as administrator** (or simply double-click it; it will ask for permission automatically).
3. Wait for the script to finish.
4. **Unplug your iPhone**, plug it back in, unlock your screen, and tap **"Trust This Computer"**.
5. Open iTunes or Sideloadly — your device will now be detected properly!

### Option 2: PowerShell One-Liner

Open PowerShell as Administrator and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\Fix-Apple-Driver.ps1
```

---

## Diagnostic Tool (`Check-Apple-Driver.ps1`)

Want to inspect your current driver status before or after running the fix?

Run:
```powershell
powershell -ExecutionPolicy Bypass -File .\Check-Apple-Driver.ps1
```

It checks:
- Current driver version for all connected Apple USB devices (`538.0.0.0` vs `6.0.9999.69`)
- Driver Store contents for rogue `oem*.inf` entries
- `Apple Mobile Device Service` operational status

---

## Manual Step-by-Step Fix

If you prefer doing this manually without running scripts:

1. **Delete the Rogue Driver:**
   Open Command Prompt / PowerShell as Administrator and run:
   ```cmd
   pnputil /enum-drivers
   ```
   Look for the `oem##.inf` that has `Driver Version: ... 538.0.0.0`. Then run:
   ```cmd
   pnputil /delete-driver oem##.inf /uninstall /force
   ```

2. **Reinstall the Official Driver:**
   ```cmd
   pnputil /add-driver "C:\Program Files\Common Files\Apple\Mobile Device Support\Drivers\usbaapl64.inf" /install
   ```

3. **Rescan Hardware & Restart Service:**
   ```cmd
   pnputil /scan-devices
   net stop "Apple Mobile Device Service"
   net start "Apple Mobile Device Service"
   ```

4. **Block Windows Update from Reinstalling Drivers:**
   ```powershell
   New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord -Force
   ```

---

## Additional Troubleshooting

### 1. `LOCKDOWN_E_MUX_ERROR` persists in Sideloadly
If you still see `LOCKDOWN_E_MUX_ERROR` after running the fix:
- Open Sideloadly -> **Advanced Options**
- Check **"Remove App Extensions"**
- Check **"Change App Bundle ID"** (add a random letter/number to the end to bypass cached iOS bundle collisions)

### 2. iTunes says "Could not connect to this iPhone (0xE8000065)"
- Avoid front-panel USB case headers or unpowered hubs; plug the cable directly into a rear motherboard USB port.
- Ensure you unlock your iPhone screen before or immediately after plugging in the cable so the "Trust This Computer" dialog appears.

### 3. Resetting Corrupted Trust / Pairing Keys
If the phone was connected while the bad driver was active, the pairing keys in Windows may be corrupt. In an elevated PowerShell prompt:
```powershell
Stop-Service -Name "Apple Mobile Device Service" -Force
Remove-Item -Path "C:\ProgramData\Apple\Lockdown\*" -Recurse -Force
Start-Service -Name "Apple Mobile Device Service"
```
Then unplug and replug the iPhone and tap **Trust**.

---

## Authors & Contributors

- **[ludzof](https://github.com/ludzof)** — Project Creator & Maintainer
- **[Antigravity](https://deepmind.google/)** (Google DeepMind) — Diagnostic Engineering & Script Development

---

## License

This project is licensed under the [MIT License](LICENSE).
