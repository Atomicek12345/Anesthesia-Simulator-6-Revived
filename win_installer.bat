@echo off
set "BAT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ((Get-Content -LiteralPath $env:BAT_PATH | Select-Object -Skip 5) -join [Environment]::NewLine)"
pause
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
        winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
        
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

# Create Desktop shortcuts
$desktop = [Environment]::GetFolderPath("Desktop")
$wsh = New-Object -ComObject WScript.Shell
$iconPath = Join-Path $InstallDir "images\favicon.ico"

function Make-Shortcut($name, $targetFile) {
    $lnk = $wsh.CreateShortcut((Join-Path $desktop "$name.lnk"))
    $lnk.TargetPath = $targetFile
    $lnk.WorkingDirectory = $InstallDir
    if (Test-Path $iconPath) { $lnk.IconLocation = $iconPath }
    $lnk.Save()
}

$indexPath  = Join-Path $InstallDir "index.html"
$lookupPath = Join-Path $InstallDir "lookup.html"

Make-Shortcut "Anesthesia Simulator 6" $indexPath
Write-Host "Created Desktop shortcut: Anesthesia Simulator 6"
Start-Process $indexPath

if (Test-Path $lookupPath) {
    Make-Shortcut "Anesthesia Lookup" $lookupPath
    Write-Host "Created Desktop shortcut: Anesthesia Lookup"
    Start-Process $lookupPath
} else {
    Write-Host "Note: lookup.html was not in the patch, skipped its shortcut/launch." -ForegroundColor Yellow
}

Write-Host "`nAll done! Enjoy the simulator." -ForegroundColor Cyan
