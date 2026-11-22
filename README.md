# Anesthesia Simulator 6 - Custom Mod Patch

## [**Page with tools!**](https://atomicek12345.github.io/Anesthesia-Simulator-6-Revived/)

A community modification for **Anesoft Anesthesia Simulator 6**. This repository contains only the patch file for the modifications and does not redistribute any original game assets or proprietary code.

<img width="1919" height="1079" alt="sim1" src="https://github.com/user-attachments/assets/826c0fd0-fc4e-4cf7-8b4f-1c18ac79b111" />

## Prerequisites

1. **Original Game Files:** You must hold a clean copy of the original **DEMO** program files (**350 files in total**).<br>
Official **Anesoft** [website](https://anesoft.com/demos/anesth6/index.html). Hint: use the dev console :)
3. Use the included [File Verifier](https://atomicek12345.github.io/Anesthesia-Simulator-6-Revived/) to verify your directory structure.
4. **Git:** You need [Git](https://git-scm.com/downloads) installed on your system to apply the `.patch` file.

<img width="1317" height="922" alt="lookuptool" src="https://github.com/user-attachments/assets/92cd4579-a732-428c-b92d-635f4f9b4422" />

## Installation Instructions

chmod +x install_linux_mac.sh && ./install_linux_mac.sh

1. Make sure you have all the **350 original DEMO files** in a clean folder on your computer.
2. Make a backup of the unmodified files for future updates.
3. Download `anesthesia_mod.patch` from the latest release and place it directly inside that same folder (alongside the original files).
4. Open a terminal or command prompt inside your game folder.
5. Run the following command to apply the changes:
```bash
git apply --whitespace=nowarn anesthesia_mod.patch
```
Troubleshooting
"Patch does not apply" error: Ensure your base folder contains the exact, unedited 350 files from the demo program and that no files have been renamed or moved.

Reverting changes: To undo the mod and restore the original game, run:
```bash
git apply -R anesthesia_mod.patch
```
Disclaimer <br>
This is an unofficial, non-commercial educational modification/revival project of the legacy Anesthesia Simulator 6. All original trademarks, media, and case scenarios remain the intellectual property of Anesoft Corporation. No commercial use is intended or permitted.

If you encounter any difficulties, you can always DM me here or on Discord: atomicek1234
