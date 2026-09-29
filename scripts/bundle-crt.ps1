# Copies the Microsoft Visual C++ runtime into a Windows release bundle so
# the shipped application does not depend on the end user having installed the
# redistributable.
#
# Sources, in order of preference:
#   1. -RedistDir pointing at an extracted vc_redist.*.exe payload
#   2. The GitHub Actions runner's MSVC toolchain redist directory
#   3. The local System32 copy (developer machines; a warning is emitted
#      because redistributable terms do not permit redistributing it from
#      there, so it is used only to *verify*, never staged automatically
#      unless -AllowSystemRuntime is passed)
#
# Usage: powershell -File scripts/bundle-crt.ps1 [-BuildDir path] [-RedistDir path] [-AllowSystemRuntime]
param(
    [string]$BuildDir = "build/windows/x64/runner/Release",
    [string]$RedistDir,
    [switch]$AllowSystemRuntime
)

$ErrorActionPreference = "Stop"

# x64 redistributable payloads.  msvcp140 is only needed by the C++ standard
# library that TagLib links against; the two vcruntime DLLs are required by
# the app itself.
$Required = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")

if (-not (Test-Path $BuildDir)) {
    Write-Error "Build directory '$BuildDir' not found. Build first: flutter build windows --release"
}

function Resolve-RedistDir {
    if ($RedistDir) {
        if (-not (Test-Path $RedistDir)) {
            Write-Error "RedistDir '$RedistDir' does not exist."
        }
        return $RedistDir
    }

    # GitHub-hosted Windows runners carry several VS toolchains; take the
    # newest one that has a redist payload.
    $vsRoot = "C:\Program Files\Microsoft Visual Studio"
    if (Test-Path $vsRoot) {
        $candidates = Get-ChildItem -Path $vsRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                Get-ChildItem -Path $_.FullName -Recurse -Filter "VC" -Directory -ErrorAction SilentlyContinue
            }
        foreach ($c in $candidates) {
            $redist = Join-Path $c.FullName "Redist\MSVC"
            if (Test-Path $redist) {
                $latest = Get-ChildItem -Path $redist -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
                if ($latest) {
                    $payload = Join-Path $latest.FullName "x64\Microsoft.VC143.CRT"
                    if (Test-Path $payload) { return $payload }
                }
            }
        }
    }

    $system32 = Join-Path $env:SystemRoot "System32"
    if (Test-Path $system32) { return $system32 }
    return $null
}

$source = Resolve-RedistDir
if (-not $source) {
    Write-Error "Could not locate any Visual C++ runtime payload on this machine."
}

$fromSystem32 = ($source -eq (Join-Path $env:SystemRoot "System32"))
if ($fromSystem32 -and -not $AllowSystemRuntime) {
    Write-Error @"
Only the System32 copy of the VC++ runtime was found, which comes from an
installed redistributable and is not licensed for redistribution.
Install the Visual Studio Build Tools (or pass -RedistDir pointing at an
extracted vc_redist.*.exe) and re-run, or pass -AllowSystemRuntime to stage
the System32 copy anyway for a local smoke test.
"@
}

$copied = @()
$missing = @()
foreach ($dll in $Required) {
    $src = Join-Path $source $dll
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $BuildDir $dll) -Force
        $copied += $dll
        Write-Host "OK   staged $dll"
    } else {
        $missing += $dll
    }
}

if ($missing.Count -gt 0) {
    Write-Error "VC++ runtime DLLs not found in '$source': $($missing -join ', ')"
}

Write-Host ""
Write-Host "VC++ runtime staged from $source ($($copied.Count)/$($Required.Count) files)" -ForegroundColor Green
