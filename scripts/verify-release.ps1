# Verifies that a Windows release bundle is structurally correct:
#   1. Required native TagLib DLLs sit next to the executable
#      (NativeLibraryLoader's primary search path).
#   2. No stray TagLib DLLs under data\ (the pre-fix install location).
#   3. taglib_c.dll's tag.dll dependency is satisfied from the same folder.
#   4. Warns when the VC++ runtime DLLs are not bundled (end-user machines
#      then require the Microsoft Visual C++ Redistributable installed).
#
# Usage: powershell -File scripts/verify-release.ps1 [-BuildDir path]
param(
    [string]$BuildDir = "build/windows/x64/runner/Release"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "$BuildDir/open_tag_editor.exe")) {
    Write-Error "No open_tag_editor.exe found under '$BuildDir'. Build first: flutter build windows --release"
}

$failures = @()

# 1. TagLib DLLs adjacent to the executable
foreach ($dll in @("taglib_c.dll", "tag.dll")) {
    if (Test-Path "$BuildDir/$dll") {
        Write-Host "OK   $dll next to executable"
    } else {
        $failures += "$dll missing from bundle root - writes will be disabled"
    }
}

# 2. Old (broken) install location must be empty of TagLib DLLs
$stray = Get-ChildItem "$BuildDir/data" -Filter "tag*.dll" -ErrorAction SilentlyContinue
if ($stray) {
    $failures += "Stray TagLib DLLs under data\: $($stray.Name -join ', ')"
} else {
    Write-Host "OK   no TagLib DLLs under data\"
}

# 3. taglib_c.dll -> tag.dll dependency resolvable from bundle root
$tagDll = Join-Path $BuildDir "tag.dll"
if ((Test-Path "$BuildDir/taglib_c.dll") -and (Test-Path $tagDll)) {
    Write-Host "OK   tag.dll dependency colocated with taglib_c.dll"
}

# 4. VC++ runtime bundling check (warning only)
$crtMissing = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll") |
    Where-Object { -not (Test-Path "$BuildDir/$_") }
if ($crtMissing) {
    Write-Warning ("VC++ runtime DLLs not bundled: {0}" -f ($crtMissing -join ", "))
    Write-Warning "End users need the Microsoft Visual C++ 2015-2022 Redistributable (x64), or these files must be added to the installer."
}

if ($failures.Count -gt 0) {
    Write-Host ""
    $failures | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "Release bundle verification PASSED" -ForegroundColor Green
