param(
  [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $ProjectDir "bin\Release\net10.0\$Runtime"
$Zip = Join-Path $ProjectDir "DeskAlert-$Runtime.zip"
$Exe = Join-Path $Out "DeskAlert.exe"

Write-Host "Publishing"
dotnet publish (Join-Path $ProjectDir "DeskAlert.csproj") -c Release -r $Runtime

if (-not (Test-Path $Out)) {
  Write-Error "Publish output not found: $Out"
}

if (-not (Test-Path $Exe)) {
  Write-Error "Executable not found: $Exe"
}

Write-Host "Deploying Qt runtime (windeployqt)"
$windeployqt = Get-Command windeployqt -ErrorAction SilentlyContinue
if (-not $windeployqt) {
  Write-Error "windeployqt not found in PATH. Add your Qt bin directory to PATH (e.g. C:\Qt\6.x.x\msvcXXXX_64\bin)."
}

& $windeployqt.Source --qmldir (Join-Path $ProjectDir "Application") $Exe

$QtMultimediaQmlDir = Join-Path $Out "qml\QtMultimedia"
if (-not (Test-Path $QtMultimediaQmlDir)) {
  Write-Warning "QtMultimedia QML module folder not found at: $QtMultimediaQmlDir"
  Write-Warning "If app still fails, make sure Qt Multimedia is installed for your Qt kit and rerun."
}

Write-Host "Packaging"
if (Test-Path $Zip) { Remove-Item $Zip -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Out, $Zip)

Write-Host "Done: $Zip"
