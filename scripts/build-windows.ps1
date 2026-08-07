param(
  [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $ProjectDir "bin\Release\net10.0\$Runtime"
$Zip = Join-Path $ProjectDir "DeskAlert-$Runtime.zip"

Write-Host "Publishing"
dotnet publish (Join-Path $ProjectDir "DeskAlert.csproj") -c Release -r $Runtime

if (-not (Test-Path $Out)) {
  Write-Error "Publish output not found: $Out"
}

Write-Host "Packaging"
if (Test-Path $Zip) { Remove-Item $Zip }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Out, $Zip)

Write-Host "Done: $Zip"
