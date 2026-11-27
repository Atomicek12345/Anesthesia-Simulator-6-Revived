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

# The launcher needs Python 3 (no root needed, it's only used to serve the files locally)
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required for the launcher but was not found."
  echo "  macOS : run 'xcode-select --install' (or install from https://www.python.org/downloads/)"
  echo "  Linux : install the 'python3' package with your package manager"
  exit 1
fi
PYTHON_BIN="$(command -v python3)"

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

# Apply patch with git or patch (both are normally preinstalled; nothing here needs root)
cd "$INSTALL_DIR"
if command -v git >/dev/null 2>&1; then
  git init -q
  git apply --ignore-whitespace --whitespace=nowarn "$PATCH_FILE"
  rm -rf .git
elif command -v patch >/dev/null 2>&1; then
  patch -p1 -l < "$PATCH_FILE"
else
  echo "Neither 'git' nor 'patch' was found, and one of them is needed to apply the patch."
  echo "Please install one (e.g. 'sudo apt install patch', 'sudo dnf install patch', 'brew install git')"
  echo "and run this installer again."
  exit 1
fi
rm -f "$PATCH_FILE"
echo "Patch applied successfully!"

# ------------------------------------------------------------------
# Combined launcher: one terminal window, one server, game + lookup
# ------------------------------------------------------------------
cat > "$INSTALL_DIR/StartServer.py" <<'PYEOF'
#!/usr/bin/env python3
import atexit
import mimetypes
import os
import platform
import select
import shutil
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

ROOT = os.path.realpath(os.path.dirname(os.path.abspath(__file__)))
PROFILES = os.path.join(ROOT, "_profiles")
PAGES = {"game": "index.html", "lookup": "lookup.html"}
HAS_LOOKUP = os.path.isfile(os.path.join(ROOT, "lookup.html"))
IS_MAC = platform.system() == "Darwin"
DEVNULL = subprocess.DEVNULL

MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".mjs": "application/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".wasm": "application/wasm",
    ".wav": "audio/wav",
    ".mp3": "audio/mpeg",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
}

# Small script appended to served pages: tells the server when a page loads / is closed
INJECT = ("<script>(function(){var p='@@';function s(u){try{navigator.sendBeacon('/__'+u+'?p='+p)}"
          "catch(e){}}s('hello');window.addEventListener('pagehide',function(){s('bye')});})();</script>")

lock = threading.Lock()
st = {n: {"open": False, "started": 0.0, "bye": None, "proc": None, "tracked": False} for n in PAGES}
running = True
PREFIX = ""


def say(msg=""):
    try:
        print(msg, flush=True)
    except Exception:
        pass


# ---------------- HTTP server ----------------
class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _send(self, code, body=b"", ctype=None):
        self.send_response(code)
        if ctype:
            self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body and self.command != "HEAD":
            self.wfile.write(body)

    def handle_any(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
            if n:
                self.rfile.read(n)
            parsed = urlparse(self.path)
            rel = unquote(parsed.path).lstrip("/") or "index.html"

            if rel in ("__hello", "__bye"):
                name = parse_qs(parsed.query).get("p", [""])[0]
                if name in st:
                    with lock:
                        if rel == "__hello":
                            st[name]["open"] = True
                            st[name]["bye"] = None
                        else:
                            st[name]["bye"] = time.time()
                return self._send(204)

            full = os.path.realpath(os.path.join(ROOT, rel))
            inside = full.startswith(ROOT + os.sep)
            hidden = rel.startswith("_profiles") or rel.startswith(".")
            if not inside or hidden or not os.path.isfile(full):
                return self._send(404)

            ext = os.path.splitext(full)[1].lower()
            ctype = MIME.get(ext) or mimetypes.guess_type(full)[0] or "application/octet-stream"
            with open(full, "rb") as f:
                body = f.read()
            page = {"index.html": "game", "lookup.html": "lookup"}.get(rel.lower())
            if page:
                body += INJECT.replace("@@", page).encode("ascii")
            self._send(200, body, ctype)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass
        except Exception:
            try:
                self._send(500)
            except Exception:
                pass

    do_GET = do_POST = do_HEAD = handle_any


# ---------------- Browser helpers ----------------
def find_browser():
    if IS_MAC:
        chromium = []
        for base in ("/Applications", os.path.expanduser("~/Applications")):
            chromium += [
                base + "/Google Chrome.app/Contents/MacOS/Google Chrome",
                base + "/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
                base + "/Brave Browser.app/Contents/MacOS/Brave Browser",
                base + "/Chromium.app/Contents/MacOS/Chromium",
            ]
        for p in chromium:
            if os.path.isfile(p):
                return ("chromium", p)
        for base in ("/Applications", os.path.expanduser("~/Applications")):
            p = base + "/Firefox.app/Contents/MacOS/firefox"
            if os.path.isfile(p):
                return ("firefox", p)
        return None
    for name in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
                 "microsoft-edge", "microsoft-edge-stable", "brave-browser"):
        p = shutil.which(name)
        if p:
            return ("chromium", p)
    p = shutil.which("firefox")
    if p:
        return ("firefox", p)
    return None


def open_page(name):
    url = PREFIX + PAGES[name]
    s = st[name]
    with lock:
        s["open"] = True
        s["started"] = time.time()
        s["bye"] = None
    b = find_browser()
    try:
        if b:
            kind, exe = b
            # Separate profile per window so each one can be closed independently
            prof = os.path.join(PROFILES, "AnesSim6_" + name)
            os.makedirs(prof, exist_ok=True)
            if kind == "chromium":
                args = [exe, "--user-data-dir=" + prof, "--app=" + url, "--no-first-run",
                        "--no-default-browser-check", "--disable-session-crashed-bubble",
                        "--hide-crash-restore-bubble"]
            else:
                args = [exe, "--no-remote", "--profile", prof, "--new-window", url]
            s["proc"] = subprocess.Popen(args, stdout=DEVNULL, stderr=DEVNULL, stdin=DEVNULL,
                                         start_new_session=True)
            s["tracked"] = True
        else:
            opener = ["open", url] if IS_MAC else ["xdg-open", url]
            subprocess.Popen(opener, stdout=DEVNULL, stderr=DEVNULL, stdin=DEVNULL,
                             start_new_session=True)
            s["tracked"] = False
    except Exception as e:
        say("Could not open a browser automatically (%s). Open this address manually:\n  %s" % (e, url))
        s["tracked"] = False


def browser_running(name):
    if shutil.which("pgrep"):
        return subprocess.run(["pgrep", "-f", "AnesSim6_" + name],
                              stdout=DEVNULL, stderr=DEVNULL).returncode == 0
    p = st[name]["proc"]
    return bool(p and p.poll() is None)


def close_browser(name):
    p = st[name]["proc"]
    if p and p.poll() is None:
        try:
            os.killpg(p.pid, signal.SIGTERM)
        except Exception:
            pass
    if shutil.which("pkill"):
        subprocess.run(["pkill", "-f", "AnesSim6_" + name], stdout=DEVNULL, stderr=DEVNULL)
    st[name]["proc"] = None


def on_closed(name):
    global running
    with lock:
        st[name]["open"] = False
        st[name]["bye"] = None
    close_browser(name)
    if name == "game":
        say("\nGame window closed - shutting down...")
        running = False
    else:
        say("\nLookup closed. Press L to open it again.")


def request_stop(*_):
    global running
    running = False


def main():
    global running, PREFIX

    # Listener: fixed port first (keeps browser-saved data stable), else any free port
    httpd = None
    for port in (8642, 0):
        try:
            ThreadingHTTPServer.daemon_threads = True
            httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue
    if httpd is None:
        say("Could not start the local server.")
        sys.exit(1)
    PREFIX = "http://127.0.0.1:%d/" % httpd.server_address[1]
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, request_stop)

    # Watchdog: if this window is killed/closed, close the browser windows too
    wd = 'while kill -0 %d 2>/dev/null; do sleep 1; done; pkill -f "[A]nesSim6_(game|lookup)"' % os.getpid()
    try:
        subprocess.Popen(["sh", "-c", wd], stdin=DEVNULL, stdout=DEVNULL, stderr=DEVNULL,
                         start_new_session=True)
    except Exception:
        pass

    # Keyboard (cbreak mode on the controlling terminal)
    tty_f = None
    old_attrs = None
    try:
        import termios
        import tty as ttymod
        tty_f = open("/dev/tty", "rb", buffering=0)
        old_attrs = termios.tcgetattr(tty_f.fileno())
        ttymod.setcbreak(tty_f.fileno())
    except Exception:
        tty_f = None

    def restore_tty():
        if tty_f is not None and old_attrs is not None:
            try:
                import termios
                termios.tcsetattr(tty_f.fileno(), termios.TCSADRAIN, old_attrs)
            except Exception:
                pass

    atexit.register(restore_tty)

    say("==================================================")
    say("  Anesthesia Simulator 6 Local Server")
    say("  Running at: " + PREFIX)
    say("--------------------------------------------------")
    if HAS_LOOKUP:
        say("  [L] Reopen Lookup")
    say("  [Q] Quit (closes everything)")
    say("  Closing the game window also closes this window.")
    say("==================================================")

    open_page("game")
    if HAS_LOOKUP:
        open_page("lookup")

    last_poll = time.time()
    try:
        while running:
            # Keyboard
            if tty_f is not None:
                r, _, _ = select.select([tty_f], [], [], 0.2)
                if r:
                    ch = os.read(tty_f.fileno(), 1).decode(errors="ignore").lower()
                    if ch == "l":
                        if not HAS_LOOKUP:
                            say("Lookup is not installed.")
                        elif st["lookup"]["open"]:
                            say("Lookup is already open.")
                        else:
                            say("Opening Lookup...")
                            open_page("lookup")
                    elif ch == "q":
                        running = False
            else:
                time.sleep(0.2)

            # Closed-window detection
            now = time.time()
            do_poll = now - last_poll >= 2
            if do_poll:
                last_poll = now
            for name in ("game", "lookup"):
                s = st[name]
                if not s["open"]:
                    continue
                closed = False
                # Page said goodbye and didn't come back (a reload sends hello again within seconds)
                if s["bye"] and now - s["bye"] > 3:
                    closed = True
                # Backup: dedicated browser process is gone
                elif s["tracked"] and do_poll and now - s["started"] > 8:
                    p = s["proc"]
                    if p is not None and p.poll() is not None and not browser_running(name):
                        closed = True
                if closed:
                    on_closed(name)
                if not running:
                    break
    finally:
        close_browser("game")
        close_browser("lookup")
        try:
            httpd.shutdown()
        except Exception:
            pass
        restore_tty()


if __name__ == "__main__":
    main()
PYEOF
chmod +x "$INSTALL_DIR/StartServer.py"

# ------------------------------------------------------------------
# Desktop shortcut (one, starts game + lookup)
# ------------------------------------------------------------------
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  DESKTOP="$HOME/Desktop"
  mkdir -p "$DESKTOP"
  # Remove shortcuts from older installs
  rm -f "$DESKTOP/Anesthesia Lookup.webloc" "$DESKTOP/Anesthesia Simulator 6.webloc" "$DESKTOP/Anesthesia Lookup.command"
  CMD_FILE="$DESKTOP/Anesthesia Simulator 6.command"
  cat > "$CMD_FILE" <<EOF
#!/bin/bash
exec "$PYTHON_BIN" "$INSTALL_DIR/StartServer.py"
EOF
  chmod +x "$CMD_FILE"
  echo "Created Desktop shortcut: Anesthesia Simulator 6 (opens game + lookup)"
else
  DESKTOP="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
  mkdir -p "$DESKTOP"
  # Remove shortcuts from older installs
  rm -f "$DESKTOP/AnesthesiaLookup.desktop"
  DF="$DESKTOP/AnesthesiaSimulator6.desktop"
  cat > "$DF" <<EOF
[Desktop Entry]
Type=Application
Name=Anesthesia Simulator 6
Exec="$PYTHON_BIN" "$INSTALL_DIR/StartServer.py"
Icon=${INSTALL_DIR}/images/favicon.ico
Terminal=true
Categories=Education;Medical;
EOF
  chmod +x "$DF"
  command -v gio >/dev/null 2>&1 && gio set "$DF" metadata::trusted true 2>/dev/null || true
  echo "Created Desktop shortcut: Anesthesia Simulator 6 (opens game + lookup)"
fi

if [ ! -f "$INSTALL_DIR/lookup.html" ]; then
  echo "Note: lookup.html was not in the patch, only the game will open."
fi

echo "All done! Starting..."
exec "$PYTHON_BIN" "$INSTALL_DIR/StartServer.py"
