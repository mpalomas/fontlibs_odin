#Requires -Version 7.4
<#
Downloads the prebuilt FreeType and HarfBuzz libraries that match the committed sources and configuration into
lib/<os>-<arch>/, from the GitHub release named in upstream/release.env (written by .github/workflows/build-fontlibs.yml). The
PowerShell version of tools/fetch_fontlibs_libs.sh.

Usage: tools/fetch_fontlibs_libs.ps1 [PLATFORM...]
  PLATFORM  windows-x86_64, linux-x86_64 or macos-arm64 (default: this machine's)

Checks the release's configuration (fontlibs_ftoption.h, fontlibs_ftmodule.h, fontlibs_harfbuzz.cc) and the versions of the sources
against the committed ones, and the downloads against the release's SHA256SUMS. Uses gh when it is installed and logged in, else
Invoke-WebRequest.
Environment:
  FONTLIBS_RELEASE_REPO  (default: mpalomas/fontlibs_odin)
  FONTLIBS_RELEASE_URL   Base URL of the release downloads, without gh (default: the repository's releases)
#>
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Platforms
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = Split-Path -Parent $PSScriptRoot
$Slug = $env:FONTLIBS_RELEASE_REPO ? $env:FONTLIBS_RELEASE_REPO : 'mpalomas/fontlibs_odin'
$BaseUrl = $env:FONTLIBS_RELEASE_URL ? $env:FONTLIBS_RELEASE_URL : "https://github.com/$Slug/releases/download"
$Pin = Join-Path $Repo 'upstream/release.env'
$Config = 'fontlibs_ftoption.h', 'fontlibs_ftmodule.h', 'fontlibs_harfbuzz.cc'

if (-not (Test-Path $Pin)) { throw "no ${Pin}: the committed sources do not come from a release. Build the libraries with tools/build_fontlibs.ps1" }
$Match = Select-String -Path $Pin -Pattern '^RELEASE_TAG=(.+)$'
if (-not $Match) { throw "no RELEASE_TAG in ${Pin}: no release matches the committed sources. Build the libraries with tools/build_fontlibs.ps1" }
$Tag = $Match.Matches.Groups[1].Value

if (-not $Platforms) {
    $os = $IsWindows ? 'windows' : $IsMacOS ? 'macos' : $IsLinux ? 'linux' : (throw 'unsupported OS')
    $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
        'X64' { 'x86_64' }
        'Arm64' { 'arm64' }
        default { throw "unsupported architecture $_" }
    }
    $Platforms = @("$os-$arch")
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) "fontlibs_libs_$PID"
New-Item -ItemType Directory -Force $Tmp | Out-Null
try {
    $files = $Config + @('sources.env', 'SHA256SUMS') + ($Platforms | ForEach-Object { "fontlibs-$_.tar.gz" })

    Write-Host "Downloading $($files -join ' ') from release $Tag of $Slug"
    $gh = -not $env:FONTLIBS_RELEASE_URL -and (Get-Command gh -ErrorAction SilentlyContinue)
    if ($gh) {
        try { gh auth status 2>&1 | Out-Null } catch { $gh = $false }
    }
    if ($gh) {
        gh release download $Tag --repo $Slug --dir $Tmp @($files | ForEach-Object { '--pattern', $_ })
    } else {
        foreach ($f in $files) {
            try {
                Invoke-WebRequest -MaximumRetryCount 3 -OutFile "$Tmp/$f" "$BaseUrl/$Tag/$f"
            } catch {
                throw "cannot download ${f}: $($_.Exception.Message)"
            }
        }
    }
    foreach ($f in $files) {
        if (-not (Test-Path "$Tmp/$f")) { throw "release $Tag has no $f" }
    }

    # "<sha256>  <file>" or "<sha256> *<file>"
    $sums = @{}
    foreach ($line in Get-Content "$Tmp/SHA256SUMS") {
        if ($line -match '^([0-9a-f]{64}) [ *](.+)$') { $sums[$Matches[2]] = $Matches[1] }
    }
    foreach ($f in $files | Where-Object { $_ -ne 'SHA256SUMS' }) {
        if (-not $sums.ContainsKey($f)) { throw "$f is not in the release's SHA256SUMS" }
        if ((Get-FileHash -Algorithm SHA256 "$Tmp/$f").Hash -ne $sums[$f].ToUpperInvariant()) { throw "checksum mismatch for $f" }
    }

    # The libraries must be built from the committed versions of FreeType and HarfBuzz, with the committed configuration. Compared
    # without the CRs that a checkout with core.autocrlf may have added.
    function Get-Text([string]$Path) { (Get-Content -Raw $Path) -replace "`r", '' }
    foreach ($f in $Config) {
        if ((Get-Text "$Tmp/$f") -cne (Get-Text (Join-Path $Repo "upstream/config/$f"))) {
            throw "upstream/config/$f differs from release ${Tag}'s: the configuration changed since. Build the libraries with tools/build_fontlibs.ps1"
        }
    }
    $committed = (Get-Content $Pin | Where-Object { $_ -match '^(FREETYPE|HARFBUZZ)_' }) -join "`n"
    $released = (Get-Content "$Tmp/sources.env" | Where-Object { $_ -match '^(FREETYPE|HARFBUZZ)_' }) -join "`n"
    if ($committed -cne $released) {
        throw "the versions in upstream/release.env differ from release ${Tag}'s: the sources were updated since. Build the libraries with tools/build_fontlibs.ps1"
    }

    foreach ($platform in $Platforms) {
        # The archives hold lib/<platform>/<libraries>. tar is in Windows 10 and later.
        tar -xzf "$Tmp/fontlibs-$platform.tar.gz" -C $Repo
        Write-Host "Extracted to lib/${platform}/:"
        Get-ChildItem (Join-Path $Repo "lib/$platform") | Format-Table Name, Length -AutoSize | Out-Host
    }
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
