Param(
  [switch]$Sign
)

# Script to rename the executable and build the Inno Setup installer.
# Expected location: this script in scripts
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Resolve build directory relative to repository root (scripts is at repo-root/scripts)
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$buildDir = Resolve-Path (Join-Path $repoRoot "build\windows\x64\runner\Release") -ErrorAction SilentlyContinue
if (-not $buildDir) {
  Write-Error "Build directory not found: $($repoRoot)\build\windows\x64\runner\Release"
  exit 1
}
$buildDir = $buildDir.Path

$src = Join-Path $buildDir "paperlessngx_uploader.exe"

if (-not (Test-Path $src)) {
  Write-Error "Source executable not found: $src"
  exit 1
}

# Path to Inno Setup compiler and .iss. Assume installer files are in windows\installer relative to repo root
$iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$iss = Resolve-Path (Join-Path $repoRoot "windows\installer\paperless_ngx_uploader.iss") -ErrorAction SilentlyContinue

if (-not (Test-Path $iscc)) {
  Write-Error "ISCC.exe not found at: $iscc. Install Inno Setup or adjust the path."
  exit 1
}
if (-not $iss) {
  Write-Error ".iss file not found: $($repoRoot)\windows\installer\paperless_ngx_uploader.iss"
  exit 1
}
$iss = $iss.Path

# Compile the installer
Write-Output "Running ISCC on $iss"
& $iscc $iss
$exit = $LASTEXITCODE
if ($exit -ne 0) {
  Write-Error "ISCC failed with exit code $exit"
  exit $exit
}

# Optional signing
if ($Sign) {
  # The Inno Setup output typically goes to windows\installer\Output by the .iss script; keep that convention
  $installer = Resolve-Path (Join-Path $repoRoot "windows\installer\Output\PaperlessNGX_Uploader_Installer_Windows_x64.exe") -ErrorAction SilentlyContinue
  if ($installer -and (Test-Path $installer.Path)) {
    Write-Output "Signing installer: $($installer.Path)"
    & signtool sign /a /tr http://timestamp.digicert.com /td sha256 /fd sha256 $installer.Path
  } else {
    Write-Warning "Installer not found to sign: $($repoRoot)\windows\installer\Output\PaperlessNGX_Uploader_Installer_Windows_x64.exe"
  }
}

Write-Output "Script completed successfully."
