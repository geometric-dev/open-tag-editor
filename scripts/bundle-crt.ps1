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

    # Locate the Visual Studio installation. vswhere is authoritative and
    # present on every GitHub-hosted runner; the glob is a fallback.
    $vsRoots = @()

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $installPath = & $vswhere -latest -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>$null
        if ($installPath) { $vsRoots += $installPath }
    }

    $vsRoot = "C:\Program Files\Microsoft Visual Studio"
    if (Test-Path $vsRoot) {
        $vsRoots += Get-ChildItem -Path $vsRoot -Directory -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    }

    # The redistributable payload ships as
    #   <vs>\VC\Tools\MSVC\<ver>\Redist\MSVC\<ver>\x64\Microsoft.VC*.CRT
    # (VS 18 lays it out as <vs>\VC\Redist\MSVC\<ver>\x64\...), so glob the
    # payload directory directly rather than reconstructing the path. The
    # toolset suffix (VC143, VC145, ...) and the intermediate directory
    # layout both vary between releases.
    $payloads = foreach ($root in $vsRoots) {
        Get-ChildItem -Path $root -Recurse -Depth 6 `
            -Directory -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue
    }

    # Sort key: the last path segment that parses as a version, which is the
    # redist toolset version (e.g. 14.51.36231) rather than the VC14x suffix.
    function Get-VersionKey($dir) {
        $segments = $dir.FullName -split '\\'
        [array]::Reverse($segments)
        foreach ($s in $segments) {
            $parsed = $null
            if ([version]::TryParse($s, [ref]$parsed)) { return $parsed }
        }
        return [version]'0.0'
    }

    # x64 is mandatory (the app is x64-only); prefer the newest toolset.
    $x64 = $payloads | Where-Object { $_.FullName -match '\\x64\\' } |
        Sort-Object { Get-VersionKey $_ } -Descending
    if ($x64) { return $x64[0].FullName }

    $other = $payloads | Sort-Object { Get-VersionKey $_ } -Descending
    if ($other) { return $other[0].FullName }

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
