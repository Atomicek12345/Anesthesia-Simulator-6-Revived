# Anesthesia Simulator 6 — Custom Mod Patch

A community modification for **Anesoft Anesthesia Simulator 6**. This repository contains only the patch file for the modifications and does not redistribute any original game assets or proprietary code.

## Prerequisites

1. **Original Game Files:** You must obtain a clean copy of the original **DEMO** game files (**353 files in total with just the first case (Anesth6Case1.js)**) directly from the official **Anesoft** [website](https://anesoft.com/demos/anesth6/index.html) before applying this patch.
2. It is required to manually "carve" out every file, you can verify it with the tree.txt file in this repo. Hint: use the dev console :)
3. **Git:** You need [Git](https://git-scm.com/downloads) installed on your system to apply the `.patch` file.

## Installation Instructions

1. Download all **353 original DEMO files** from the official Anesoft website into a clean folder on your computer.
2. Make a backup of the vanilla files for future updates.
3. Download `anesthesia_mod.patch` from the latest release and place it directly inside that same game folder (alongside the original files).
4. Open a terminal or command prompt inside your game folder.
5. Run the following command to apply the changes:
   ```bash
   git apply anesthesia_mod.patch
   ```
Troubleshooting
"Patch does not apply" error: Ensure your base folder contains the exact, unedited 774 files from the Anesoft website and that no files have been renamed or moved.

Reverting changes: To undo the mod and restore the original game, run:
```bash
git apply -R anesthesia_mod.patch
```
Disclaimer
This is an unofficial, fan-made patch and is not affiliated with, endorsed, or supported by Anesoft. All original game files remain the property of their respective copyright holders.

If you encounter any difficulties, you can always DM me here or on Discord: atomicek1234
