# Anesthesia Simulator 6 - Custom Mod Patch

## [**Page with tools!**](https://atomicek12345.github.io/Anesthesia-Simulator-6-Revived/)

A community modification for **Anesoft Anesthesia Simulator 6**. This repository contains only the patch file for the modifications and does not redistribute any original game assets or proprietary code.

<img width="1919" height="1079" alt="sim1" src="https://github.com/user-attachments/assets/826c0fd0-fc4e-4cf7-8b4f-1c18ac79b111" />

# Installation

No Python, manual file scraping, or terminal setup is required. The installers automatically download the official base demo files, fetch the latest patch from this repository, apply the mod, create Desktop shortcuts, and launch the simulator.

> **Install Location:**
> - **Windows:** `%USERPROFILE%\AnesthesiaSimulator6Revived`
> - **Linux / macOS:** `~/AnesthesiaSimulator6Revived`

---

### Windows (10 / 11)

1. Download **`install_windows.bat`** from the [Latest Release](https://github.com/Atomicek12345/Anesthesia-Simulator-6-Revived/releases/latest) (or directly from this repository).
2. Double-click **`install_windows.bat`** to run it.
   - *If Windows SmartScreen appears, click **More info** → **Run anyway**.*
   - *If Git is not installed on your PC, the installer will automatically install it via `winget`.*
3. Wait ~10–15 seconds for the base files and patch to finish downloading.
4. Once complete, **Anesthesia Simulator 6** (and **Anesthesia Lookup**, if included) will launch automatically in your default browser, and shortcuts will be added to your **Desktop**.

---

### Linux & macOS

1. Download **`install_linux_mac.sh`** from the [Latest Release](https://github.com/Atomicek12345/Anesthesia-Simulator-6-Revived/releases/latest) (or directly from this repository).
2. Open a terminal in the folder where you saved the file and run:
   ```bash
   chmod +x install_linux_mac.sh
   ./install_linux_mac.sh

## Manual installation

1. Make sure you have all the **350 original DEMO files** in a clean folder on your computer.
2. You may use a file verification [web app](https://atomicek12345.github.io/Anesthesia-Simulator-6-Revived/verify.html) supplied by this repo.
3. Make a backup of the unmodified files for future updates.
4. Download `anesthesia_mod.patch` from the latest release and place it directly inside that same folder (alongside the original files).
5. Open a terminal or command prompt inside your game folder.
6. Run the following command to apply the changes:
```bash
git apply --whitespace=nowarn anesthesia_mod.patch
```

## **To uninstall: Delete the AnesthesiaSimulator6Revived folder in your user directory and remove the shortcuts from your Desktop.**

<img width="1317" height="922" alt="lookuptool" src="https://github.com/user-attachments/assets/92cd4579-a732-428c-b92d-635f4f9b4422" />

Troubleshooting
"Patch does not apply" error: Ensure your base folder contains the exact, unedited 350 files from the demo program and that no files have been renamed or moved.

Reverting changes: To undo the mod and restore the original game, run:
```bash
git apply -R anesthesia_mod.patch
```
**Disclaimer:** <br>
This is an unofficial, non-commercial educational modification/revival project of the legacy Anesoft Anesthesia Simulator 6. All original trademarks, media, and case scenarios remain the intellectual property of Anesoft Corporation. No commercial use is intended or permitted. <br>
Screenshots are provided solely to demonstrate the tweaks in action; *Anesoft Anesthesia Simulator 6* and all original interface visuals remain the copyright and trademark of Anesoft Corporation.

If you encounter any difficulties, you can always DM me here or on Discord: atomicek1234
