#!/usr/bin/env bash
set -euo pipefail

DEMO_BASE="https://anesoft.com/demos/anesth6"
PATCH_URL="https://github.com/Atomicek12345/Anesthesia-Simulator-6-Revived/releases/latest/download/anesthesia_mod.patch"
PATCH_FALLBACK="https://raw.githubusercontent.com/Atomicek12345/Anesthesia-Simulator-6-Revived/main/anesthesia_mod.patch"
INSTALL_DIR="$HOME/AnesthesiaSimulator6Revived"

echo "=================================================="
echo "  Anesthesia Simulator 6 Revived - Installer"
echo "=================================================="
echo "Install folder: $INSTALL_DIR"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"/{cases,hemoWaveforms,respWaveforms,scripts,styles,sounds,images}

LIST_FILE="$INSTALL_DIR/.filelist.txt"
: > "$LIST_FILE"

{
  echo "index.html"
  echo "cases/Anesth6Case1.js"

  for p in sinus1 sinus2 sinus3 sinus4 st1 st2 st3; do
    for r in 20 30 40 50 60 70 80 90 100 120 140 160; do
      echo "hemoWaveforms/${p}_${r}.js"
    done
  done
  for r in 50 60 70 80 90 100 120 140 160; do echo "hemoWaveforms/sinus5_${r}.js"; done
  for r in 50 80; do echo "hemoWaveforms/sinus6_${r}.js"; done
  printf '%s\n' hemoWaveforms/afib6_160.js hemoWaveforms/asyst1_20.js hemoWaveforms/vfib2_20.js hemoWaveforms/vtach3_140.js

  for p in hump nl slant; do
    for r in 4 6 8 10 12 15 20 30; do
      echo "respWaveforms/${p}_${r}.js"
    done
  done

  printf '%s\n' \
    scripts/AboutAnesthSim6.js scripts/AnesthCode.js scripts/Default.js scripts/DrugInfo.js \
    scripts/iscroll-lite.js scripts/IvAdmin.js scripts/ModelsAndFsm.js scripts/prototype.js \
    scripts/Recorder.js scripts/UserControl.js scripts/Waveform.js

  printf '%s\n' styles/AnesthSim.css styles/AnesthSim_narrow.css styles/AnesthSim_short.css

  echo "sounds/pulseOx.wav"
  for i in $(seq 40 100); do echo "sounds/po${i}.wav"; done

  printf '%s\n' \
    images/airbag.jpg images/anesthSplash.jpg images/blank.jpg images/bobbin.jpg \
    images/brokenHeart.jpg images/Desflurane.jpg images/flowmeter.jpg \
    images/ghost.jpg images/heart.jpg images/Isoflurane.jpg images/Sevoflurane.jpg \
    images/circle_bagExp.jpg images/circle_bagInsp.jpg images/circle_spontExp.jpg \
    images/circle_spontFlat.jpg images/circle_spontInsp.jpg images/circle_vent0.jpg \
    images/circle_vent1.jpg images/circle_vent2.jpg \
    images/fo_carina.jpg images/fo_esophagus.jpg images/fo_lma.jpg \
    images/fo_rightmainstem.jpg images/fo_secretions.jpg \
    images/lary_1.jpg images/lary_2.jpg images/lary_3.jpg images/lary_4.jpg

  for p in clr clrP cri doCri doFo doFoLma doFoTub doLma doTub doTubP lma msk mskP tub tubP; do
    for n in 1 2 3 4 5 6 7 8; do
      echo "images/${p}_${n}.jpg"
    done
  done
} >> "$LIST_FILE"

echo "Downloading 351 required demo files in parallel..."
export DEMO_BASE INSTALL_DIR
xargs -P 10 -I {} bash -c 'curl -fsSL "$DEMO_BASE/$1" -o "$INSTALL_DIR/$1"' _ {} < "$LIST_FILE"
rm -f "$LIST_FILE"

# Optional favicon
curl -fsSL "$DEMO_BASE/images/favicon.ico" -o "$INSTALL_DIR/images/favicon.ico" 2>/dev/null || true
echo "Base files downloaded!"

# Download patch
PATCH_FILE="$INSTALL_DIR/anesthesia_mod.patch"
echo "Downloading latest patch from GitHub..."
if ! curl -fsSL "$PATCH_URL" -o "$PATCH_FILE"; then
  echo "Release asset not found, falling back to main branch..."
  curl -fsSL "$PATCH_FALLBACK" -o "$PATCH_FILE"
fi

# Ensure git or patch is available & apply
cd "$INSTALL_DIR"
if command -v git >/dev/null 2>&1; then
  git init -q
  git apply --ignore-whitespace --whitespace=nowarn "$PATCH_FILE"
  rm -rf .git
elif command -v patch >/dev/null 2>&1; then
  patch -p1 -l < "$PATCH_FILE"
else
  echo "Installing git..."
  if command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y git
  elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y git
  elif command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm git
  elif command -v brew >/dev/null 2>&1; then brew install git
  else echo "Please install git or patch and re-run."; exit 1
  fi
  git init -q
  git apply --ignore-whitespace --whitespace=nowarn "$PATCH_FILE"
  rm -rf .git
fi
rm -f "$PATCH_FILE"
echo "Patch applied successfully!"

# Desktop shortcuts + Launch
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  DESKTOP="$HOME/Desktop"
  make_webloc() {
    local name="$1" target="$2"
    cat > "$DESKTOP/${name}.webloc" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>URL</key><string>file://${target}</string></dict></plist>
EOF
  }
  make_webloc "Anesthesia Simulator 6" "$INSTALL_DIR/index.html"
  open "$INSTALL_DIR/index.html"
  if [ -f "$INSTALL_DIR/lookup.html" ]; then
    make_webloc "Anesthesia Lookup" "$INSTALL_DIR/lookup.html"
    open "$INSTALL_DIR/lookup.html"
  else
    echo "Note: lookup.html was not in the patch, skipped its shortcut/launch."
  fi
else
  DESKTOP="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
  mkdir -p "$DESKTOP"
  make_desktop() {
    local fname="$1" title="$2" target="$3"
    local df="$DESKTOP/${fname}.desktop"
    cat > "$df" <<EOF
[Desktop Entry]
Type=Application
Name=${title}
Exec=xdg-open "file://${target}"
Icon=${INSTALL_DIR}/images/favicon.ico
Terminal=false
Categories=Education;Medical;
EOF
    chmod +x "$df"
    command -v gio >/dev/null 2>&1 && gio set "$df" metadata::trusted true 2>/dev/null || true
  }
  make_desktop "AnesthesiaSimulator6" "Anesthesia Simulator 6" "$INSTALL_DIR/index.html"
  xdg-open "file://${INSTALL_DIR}/index.html" >/dev/null 2>&1 &
  if [ -f "$INSTALL_DIR/lookup.html" ]; then
    make_desktop "AnesthesiaLookup" "Anesthesia Lookup" "$INSTALL_DIR/lookup.html"
    xdg-open "file://${INSTALL_DIR}/lookup.html" >/dev/null 2>&1 &
  else
    echo "Note: lookup.html was not in the patch, skipped its shortcut/launch."
  fi
fi

echo "All done! Shortcuts created on your Desktop."