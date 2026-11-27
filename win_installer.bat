@echo off
set "BAT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ((Get-Content -LiteralPath $env:BAT_PATH | Select-Object -Skip 5) -join [Environment]::NewLine)"
if errorlevel 1 pause
exit /b %ERRORLEVEL%
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$DemoBase     = "https://anesoft.com/demos/anesth6"
$PatchUrl     = "https://github.com/Atomicek12345/Anesthesia-Simulator-6-Revived/releases/latest/download/anesthesia_mod.patch"
$PatchFallback= "https://raw.githubusercontent.com/Atomicek12345/Anesthesia-Simulator-6-Revived/main/anesthesia_mod.patch"
$InstallDir   = Join-Path $env:USERPROFILE "AnesthesiaSimulator6Revived"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Anesthesia Simulator 6 Revived - Installer" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Install folder: $InstallDir`n"

if (Test-Path $InstallDir) {
    Write-Host "Cleaning existing installation folder..." -ForegroundColor Yellow
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
}
New-Item -ItemType Directory -Path $InstallDir | Out-Null

# Build exact 352-file list
$files = New-Object System.Collections.Generic.List[string]
$files.Add("index.html")
$files.Add("cases/Anesth6Case1.js")

$ratesAll = @("20","30","40","50","60","70","80","90","100","120","140","160")
foreach ($p in @("sinus1","sinus2","sinus3","sinus4","st1","st2","st3")) {
    foreach ($r in $ratesAll) { $files.Add("hemoWaveforms/${p}_${r}.js") }
}
foreach ($r in @("50","60","70","80","90","100","120","140","160")) { $files.Add("hemoWaveforms/sinus5_${r}.js") }
foreach ($r in @("50","80")) { $files.Add("hemoWaveforms/sinus6_${r}.js") }
$files.AddRange([string[]]@("hemoWaveforms/afib6_160.js","hemoWaveforms/asyst1_20.js","hemoWaveforms/vfib2_20.js","hemoWaveforms/vtach3_140.js"))

foreach ($p in @("hump","nl","slant")) {
    foreach ($r in @("4","6","8","10","12","15","20","30")) { $files.Add("respWaveforms/${p}_${r}.js") }
}

$files.AddRange([string[]]@(
    "scripts/AboutAnesthSim6.js","scripts/AnesthCode.js","scripts/Default.js","scripts/DrugInfo.js",
    "scripts/iscroll-lite.js","scripts/IvAdmin.js","scripts/ModelsAndFsm.js","scripts/prototype.js",
    "scripts/Recorder.js","scripts/UserControl.js","scripts/Waveform.js"
))

$files.AddRange([string[]]@("styles/AnesthSim.css","styles/AnesthSim_narrow.css","styles/AnesthSim_short.css"))

$files.Add("sounds/pulseOx.wav")
for ($i = 40; $i -le 100; $i++) { $files.Add("sounds/po${i}.wav") }

$files.AddRange([string[]]@(
    "images/airbag.jpg","images/anesthSplash.jpg","images/blank.jpg","images/bobbin.jpg",
    "images/brokenHeart.jpg","images/Desflurane.jpg","images/favicon.ico","images/flowmeter.jpg",
    "images/ghost.jpg","images/heart.jpg","images/Isoflurane.jpg","images/Sevoflurane.jpg",
    "images/circle_bagExp.jpg","images/circle_bagInsp.jpg","images/circle_spontExp.jpg",
    "images/circle_spontFlat.jpg","images/circle_spontInsp.jpg","images/circle_vent0.jpg",
    "images/circle_vent1.jpg","images/circle_vent2.jpg",
    "images/fo_carina.jpg","images/fo_esophagus.jpg","images/fo_lma.jpg",
    "images/fo_rightmainstem.jpg","images/fo_secretions.jpg",
    "images/lary_1.jpg","images/lary_2.jpg","images/lary_3.jpg","images/lary_4.jpg"
))
foreach ($p in @("clr","clrP","cri","doCri","doFo","doFoLma","doFoTub","doLma","doTub","doTubP","lma","msk","mskP","tub","tubP")) {
    for ($n = 1; $n -le 8; $n++) { $files.Add("images/${p}_${n}.jpg") }
}

foreach ($sub in @("cases","hemoWaveforms","respWaveforms","scripts","styles","sounds","images")) {
    New-Item -ItemType Directory -Path (Join-Path $InstallDir $sub) -Force | Out-Null
}

Write-Host ("Downloading {0} base demo files in parallel..." -f $files.Count)
$pool = [runspacefactory]::CreateRunspacePool(1, 12)
$pool.Open()
$jobs = @()
foreach ($rel in $files) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript({
        param($url, $dest, $relPath)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        try {
            $wc.DownloadFile($url, $dest)
            return $null
        } catch {
            if ($relPath -eq "images/favicon.ico") { return $null }
            return "$relPath : $($_.Exception.Message)"
        } finally {
            $wc.Dispose()
        }
    }).AddArgument("$DemoBase/$rel").AddArgument((Join-Path $InstallDir ($rel -replace '/','\'))).AddArgument($rel)
    $jobs += [pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() }
}

$done = 0; $errs = @()
foreach ($j in $jobs) {
    $res = $j.Pipe.EndInvoke($j.Handle)
    $j.Pipe.Dispose()
    $done++
    if ($res) { $errs += $res }
    Write-Progress -Activity "Downloading base demo files" -Status "$done / $($files.Count)" -PercentComplete (($done / $files.Count) * 100)
}
Write-Progress -Activity "Downloading base demo files" -Completed
$pool.Close(); $pool.Dispose()

if ($errs.Count -gt 0) {
    Write-Host "Failed downloads:" -ForegroundColor Red
    $errs | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "Could not download all required demo files."
}
Write-Host "Base files downloaded successfully!`n" -ForegroundColor Green

# Ensure Git is installed
function Find-GitExe {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LocalAppData\Programs\Git\cmd\git.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$gitExe = Find-GitExe
if (-not $gitExe) {
    Write-Host "Git not found. Attempting automatic install via winget..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements --scope user
        
        # Reload Machine + User PATH from Registry into current session
        $env:PATH = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [Environment]::GetEnvironmentVariable("Path", "User")
        
        $gitExe = Find-GitExe
    }
    if (-not $gitExe) {
        throw "Git is required to apply the patch. Please install Git from https://git-scm.com/download/win and re-run."
    }
}

# Download patch
$patchFile = Join-Path $InstallDir "anesthesia_mod.patch"
Write-Host "Downloading latest patch from GitHub..."
try {
    Invoke-WebRequest -Uri $PatchUrl -OutFile $patchFile -UseBasicParsing
} catch {
    Write-Host "Release asset not found, falling back to main branch..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $PatchFallback -OutFile $patchFile -UseBasicParsing
}

# Apply patch inside clean folder
Push-Location $InstallDir
try {
    & $gitExe init -q
    & $gitExe apply --ignore-whitespace --whitespace=nowarn $patchFile
    if ($LASTEXITCODE -ne 0) { throw "git apply failed with exit code $LASTEXITCODE." }
    Remove-Item ".git" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $patchFile -Force -ErrorAction SilentlyContinue
} finally {
    Pop-Location
}

# Generate the combined launcher (game + lookup, one window) inside $InstallDir
$serverScriptPath = Join-Path $InstallDir "StartServer.ps1"
$serverCode = @'
param(
    [string]$RootDir = $PSScriptRoot
)

$Host.UI.RawUI.WindowTitle = "Anesthesia Simulator 6 - Server"
$rootFull = [System.IO.Path]::GetFullPath($RootDir)

# ---------- Listener: try a fixed port first (keeps browser-saved data stable), else random ----------
$listener = $null
$port = 0
foreach ($try in @(8642, 0)) {
    $port = $try
    if ($port -eq 0) {
        $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $tcp.Start(); $port = $tcp.LocalEndpoint.Port; $tcp.Stop()
    }
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add("http://127.0.0.1:$port/")
        $l.Start()
        $listener = $l
        break
    } catch { }
}
if (-not $listener) { Write-Host "Could not start the local server." -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }
$prefix = "http://127.0.0.1:$port/"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".mjs"  = "application/javascript; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".wasm" = "application/wasm"
    ".wav"  = "audio/wav"
    ".mp3"  = "audio/mpeg"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
}

$pages = @{ game = "index.html"; lookup = "lookup.html" }
$hasLookup = Test-Path -LiteralPath (Join-Path $rootFull "lookup.html")

# Per-window state
$st = @{}
foreach ($n in @("game", "lookup")) {
    $st[$n] = @{ Open = $false; Started = [datetime]::MinValue; Bye = $null; Tracked = $false }
}

# Small script appended to served pages: tells the server when a page loads / is closed
$injectTemplate = "<script>(function(){var p='@@';function s(u){try{navigator.sendBeacon('/__'+u+'?p='+p)}catch(e){}}s('hello');window.addEventListener('pagehide',function(){s('bye')});})();</script>"

# ---------- Browser helpers ----------
function Find-Browser {
    $c = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
    )
    foreach ($p in $c) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}

function Get-BrowserProcs([string]$name) {
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*AnesSim6_$name*" }
}

function Close-Browser([string]$name) {
    Get-BrowserProcs $name | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Open-Page([string]$name) {
    $s = $st[$name]
    $url = $prefix + $pages[$name]
    $s.Open = $true
    $s.Started = Get-Date
    $s.Bye = $null
    $exe = Find-Browser
    if ($exe) {
        # Separate profile per window so each one can be closed independently
        $prof = Join-Path $env:TEMP "AnesSim6_$name"
        Start-Process -FilePath $exe -ArgumentList @("--user-data-dir=`"$prof`"", "--app=$url", "--no-first-run", "--no-default-browser-check") | Out-Null
        $s.Tracked = $true
    } else {
        Start-Process $url
        $s.Tracked = $false
    }
}

function On-Closed([string]$name) {
    $st[$name].Open = $false
    $st[$name].Bye = $null
    Close-Browser $name
    if ($name -eq "game") {
        Write-Host "`nGame window closed - shutting down..." -ForegroundColor Yellow
        $script:running = $false
    } else {
        Write-Host "`nLookup closed. Press L to open it again." -ForegroundColor Yellow
    }
}

# ---------- Request handling ----------
function Handle-Request($ctx) {
    $res = $ctx.Response
    try {
        $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
        if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }

        if ($rel -eq "__hello" -or $rel -eq "__bye") {
            $n = $ctx.Request.QueryString["p"]
            if ($n -and $st.ContainsKey($n)) {
                if ($rel -eq "__hello") { $st[$n].Open = $true; $st[$n].Bye = $null }
                else { $st[$n].Bye = Get-Date }
            }
            $res.StatusCode = 204
            return
        }

        $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull ($rel -replace '/', '\')))
        # Prevent directory traversal outside the install folder
        if ($candidate.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
            $res.ContentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
            $res.Headers.Add("Cache-Control", "no-cache")
            $bytes = [System.IO.File]::ReadAllBytes($candidate)

            $pageName = $null
            switch ($rel.ToLowerInvariant()) {
                "index.html"  { $pageName = "game" }
                "lookup.html" { $pageName = "lookup" }
            }
            if ($pageName) {
                $inj = [System.Text.Encoding]::ASCII.GetBytes($injectTemplate.Replace("@@", $pageName))
                $bytes = [byte[]]($bytes + $inj)
            }

            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.StatusCode = 200
        } else {
            $res.StatusCode = 404
        }
    } catch {
        try { $res.StatusCode = 500 } catch { }
    } finally {
        try { $res.OutputStream.Close() } catch { }
    }
}

# ---------- Watchdog: if this window is killed/closed, close the browser windows too ----------
$wd = {
    param($m)
    while (Get-Process -Id $m -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 1 }
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*AnesSim6_*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
$enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("& { $($wd.ToString()) } $PID"))
Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $enc) | Out-Null

# ---------- UI ----------
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Anesthesia Simulator 6 Local Server" -ForegroundColor Cyan
Write-Host "  Running at: $prefix" -ForegroundColor Green
Write-Host "--------------------------------------------------" -ForegroundColor Cyan
if ($hasLookup) { Write-Host "  [L] Reopen Lookup" }
Write-Host "  [Q] Quit (closes everything)"
Write-Host "  Closing the game window also closes this window." -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan

$script:running = $true
Open-Page "game"
if ($hasLookup) { Open-Page "lookup" }

$ctxTask = $listener.GetContextAsync()
$lastPoll = Get-Date

try {
    while ($script:running) {
        if ($ctxTask.Wait(150)) {
            $ctx = $ctxTask.Result
            $ctxTask = $listener.GetContextAsync()
            Handle-Request $ctx
        }

        # Keyboard
        try {
            while ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                switch ($k.Key) {
                    "L" {
                        if (-not $hasLookup) { Write-Host "Lookup is not installed." -ForegroundColor Yellow }
                        elseif ($st["lookup"].Open) { Write-Host "Lookup is already open." -ForegroundColor Yellow }
                        else { Write-Host "Opening Lookup..." -ForegroundColor Green; Open-Page "lookup" }
                    }
                    "Q" { $script:running = $false }
                }
            }
        } catch { }

        # Closed-window detection
        $now = Get-Date
        $doPoll = (($now - $lastPoll).TotalSeconds -ge 2)
        if ($doPoll) { $lastPoll = $now }

        foreach ($n in @("game", "lookup")) {
            $s = $st[$n]
            if (-not $s.Open) { continue }
            $closed = $false
            # Page said goodbye and didn't come back (a reload sends hello again within seconds)
            if ($s.Bye -and (($now - $s.Bye).TotalSeconds -gt 3)) { $closed = $true }
            # Backup: dedicated browser process is gone
            elseif ($s.Tracked -and $doPoll -and (($now - $s.Started).TotalSeconds -gt 8)) {
                if (-not (Get-BrowserProcs $n)) { $closed = $true }
            }
            if ($closed) { On-Closed $n }
            if (-not $script:running) { break }
        }
    }
} finally {
    Close-Browser "game"
    Close-Browser "lookup"
    try { $listener.Stop(); $listener.Close() } catch { }
}
'@

Set-Content -LiteralPath $serverScriptPath -Value $serverCode -Encoding UTF8

# Create one Desktop shortcut that starts game + lookup
$desktop = [Environment]::GetFolderPath("Desktop")
$wsh = New-Object -ComObject WScript.Shell
$iconPath = Join-Path $InstallDir "images\favicon.ico"
$psExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

# Remove the old separate lookup shortcut from earlier installs
$oldLookup = Join-Path $desktop "Anesthesia Lookup.lnk"
if (Test-Path -LiteralPath $oldLookup) { Remove-Item -LiteralPath $oldLookup -Force -ErrorAction SilentlyContinue }

$lnk = $wsh.CreateShortcut((Join-Path $desktop "Anesthesia Simulator 6.lnk"))
$lnk.TargetPath = $psExe
$lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$serverScriptPath`""
$lnk.WorkingDirectory = $InstallDir
if (Test-Path $iconPath) { $lnk.IconLocation = $iconPath }
$lnk.Save()
Write-Host "Created Desktop shortcut: Anesthesia Simulator 6 (opens game + lookup)"

if (-not (Test-Path -LiteralPath (Join-Path $InstallDir "lookup.html"))) {
    Write-Host "Note: lookup.html was not in the patch, only the game will open." -ForegroundColor Yellow
}

Write-Host "`nAll done! Starting..." -ForegroundColor Cyan
& $serverScriptPath
