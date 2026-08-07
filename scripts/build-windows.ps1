param(
  [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $ProjectDir "bin\Release\net10.0\$Runtime"
$Zip = Join-Path $ProjectDir "DeskAlert-$Runtime.zip"
$Exe = Join-Path $Out "DeskAlert.exe"

$QtVersion = if ($env:QT_VERSION) { $env:QT_VERSION } else { "6.7.3" }
$QtHost    = "windows"
$QtTarget  = "desktop"
$QtArch    = if ($env:QT_ARCH) { $env:QT_ARCH } else { "win64_msvc2019_64" }
$QtRoot    = if ($env:QT_ROOT_DIR) { $env:QT_ROOT_DIR } else { "C:\Qt" }

function Ensure-PythonPip {
  $py = Get-Command py -ErrorAction SilentlyContinue
  if (-not $py) { Write-Error "Python launcher 'py' not found." }

  & py -3 -m pip --version | Out-Null
  if ($LASTEXITCODE -ne 0) {
    & py -3 -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to bootstrap pip." }
  }

  & py -3 -m pip install --upgrade pip
  if ($LASTEXITCODE -ne 0) { Write-Error "Failed to upgrade pip." }
}

function Ensure-AqtInstall {
  & py -3 -m pip install --upgrade aqtinstall
  if ($LASTEXITCODE -ne 0) { Write-Error "Failed to install aqtinstall." }
}

function Ensure-QtInstalled {
  $qtBin = Join-Path $QtRoot "$QtVersion\msvc2019_64\bin"
  $windeployqt = Join-Path $qtBin "windeployqt.exe"

  if (-not (Test-Path $windeployqt)) {
    Write-Host "Installing Qt $QtVersion ($QtArch) to $QtRoot"
    & py -3 -m aqt install-qt $QtHost $QtTarget $QtVersion $QtArch -O $QtRoot -m qtmultimedia
    if ($LASTEXITCODE -ne 0) { Write-Error "aqt install-qt failed." }
  }

  if (-not (Test-Path $windeployqt)) {
    Write-Error "windeployqt.exe not found after install: $windeployqt"
  }

  return $windeployqt
}

function Resolve-QmlDir {
  $candidates = @(
    (Join-Path $ProjectDir "Application"),
    (Join-Path $ProjectDir "src\Application")
  )

  foreach ($c in $candidates) {
    if ((Test-Path $c) -and (Test-Path (Join-Path $c "Main.qml"))) {
      return $c
    }
  }

  $mainQml = Get-ChildItem -Path $ProjectDir -Recurse -Filter Main.qml -File -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($mainQml) { return $mainQml.DirectoryName }

  Write-Error "Could not locate QML directory (Main.qml)."
}

Write-Host "Publishing"
dotnet publish (Join-Path $ProjectDir "DeskAlert.csproj") -c Release -r $Runtime

if (-not (Test-Path $Out)) { Write-Error "Publish output not found: $Out" }
if (-not (Test-Path $Exe)) { Write-Error "Executable not found: $Exe" }

Ensure-PythonPip
Ensure-AqtInstall
$WinDeployQt = Ensure-QtInstalled
$QmlDir = Resolve-QmlDir

$qtBinDir = Split-Path -Parent $WinDeployQt
$env:PATH = "$qtBinDir;$env:PATH"

Write-Host "Using QML dir: $QmlDir"
Write-Host "Deploying Qt runtime with: $WinDeployQt"
& $WinDeployQt --qmldir $QmlDir $Exe
if ($LASTEXITCODE -ne 0) { Write-Error "windeployqt failed." }

Write-Host "Packaging"
if (Test-Path $Zip) { Remove-Item $Zip -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Out, $Zip)

Write-Host "Done: $Zip"
