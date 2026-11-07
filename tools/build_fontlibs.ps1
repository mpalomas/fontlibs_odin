#Requires -Version 7.4
<#
Builds FreeType and HarfBuzz from upstream/ into lib/windows-<arch>/: freetype.lib and harfbuzz.lib (static). Windows only:
Linux and macOS use tools/build_fontlibs.sh.

Usage: tools/build_fontlibs.ps1

Builds CMakeLists.txt with CMake, which finds Visual Studio itself: the newest installed by default (Visual Studio 2026, or its
Build Tools), no developer prompt needed. See CMakeLists.txt for the build.
Environment:
  CMAKE_GENERATOR  e.g. "Visual Studio 18 2026" to require that version, or Ninja (from a developer prompt)
  CFLAGS, CXXFLAGS Extra compiler flags
#>
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = Split-Path -Parent $PSScriptRoot
if (-not $IsWindows) { throw 'tools/build_fontlibs.ps1 builds on Windows: on Linux and macOS, run tools/build_fontlibs.sh' }
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { throw 'cmake is required (https://cmake.org, or Visual Studio''s "C++ CMake tools")' }

$arch, $cmakeArch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
    'X64' { 'x86_64', 'x64' }
    'Arm64' { 'arm64', 'ARM64' }
    default { throw "unsupported architecture $_" }
}
$platform = "windows-$arch"
$libDir = Join-Path $Repo "lib/$platform"
$buildDir = Join-Path $Repo "build/$platform"

$configure = @('-S', $Repo, '-B', $buildDir)
# Visual Studio generators take the architecture as a platform and build the --config below. The others (Ninja) take the
# architecture from the developer prompt, and the configuration here.
if (-not $env:CMAKE_GENERATOR -or $env:CMAKE_GENERATOR -like 'Visual Studio*') {
    $configure += '-A', $cmakeArch
} else {
    $configure += '-DCMAKE_BUILD_TYPE=Release'
}
if ($env:CFLAGS) { $configure += "-DCMAKE_C_FLAGS=$env:CFLAGS" }
if ($env:CXXFLAGS) { $configure += "-DCMAKE_CXX_FLAGS=$env:CXXFLAGS" }

# A fresh build directory, so that a change of generator or options applies.
Remove-Item -Recurse -Force $buildDir -ErrorAction SilentlyContinue
cmake @configure
cmake --build $buildDir --config Release --parallel

$files = 'freetype.lib', 'harfbuzz.lib'
New-Item -ItemType Directory -Force $libDir | Out-Null
foreach ($f in $files) { Remove-Item -Force (Join-Path $libDir $f) -ErrorAction SilentlyContinue }
cmake --install $buildDir --config Release --prefix $libDir
foreach ($f in $files) {
    if (-not (Test-Path (Join-Path $libDir $f))) { throw "the build made no $f" }
}
Write-Host "Built in lib/$platform/:"
Get-ChildItem $libDir -Include 'freetype.lib', 'harfbuzz.lib' -Recurse | Format-Table Name, Length -AutoSize | Out-Host
