<#
.SYNOPSIS
  Builds a single-file, self-contained Windows installer for one person's Samsung TV.

.DESCRIPTION
  Downloads the official Apps2Samsung source at a pinned tag, applies
  apps2samsung-preset.patch, adds preset.json, and publishes one .exe that:
    - preselects this person's Jellyfin build (preset.json "assetName"),
    - writes the Jellyfin server address into the TV app ("jellyfinServerUrl"),
    - shows its own window title and never self-updates to a stock build.

  Output: dist\Jellyfin-TV-Installer-<buildName>.exe and a .zip that adds the
  README and Apps2Samsung's license/notices.

.PARAMETER Apps2SamsungTag
  Apps2Samsung release tag the patch was made for.

.PARAMETER Dotnet
  Path to dotnet.exe (.NET 10 SDK). Defaults to the per-user install, then PATH.
#>
[CmdletBinding()]
param(
    [string]$Apps2SamsungTag = 'v2.8.1',
    [string]$Dotnet
)

$ErrorActionPreference = 'Stop'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

$root = $PSScriptRoot
$preset = Get-Content (Join-Path $root 'preset.json') -Raw | ConvertFrom-Json
if (-not $preset.buildName -or -not $preset.assetName) { throw 'preset.json needs buildName and assetName.' }

if (-not $Dotnet) {
    $userDotnet = Join-Path $env:LOCALAPPDATA 'Microsoft\dotnet\dotnet.exe'
    $Dotnet = if (Test-Path $userDotnet) { $userDotnet } else { (Get-Command dotnet -ErrorAction Stop).Source }
}
$sdks = & $Dotnet --list-sdks
if (-not ($sdks -match '^10\.')) { throw ".NET 10 SDK not found (dotnet: $Dotnet)." }

# Short work path: Apps2Samsung's deep source tree trips Windows' 260-char path limit.
$work = Join-Path $env:TEMP "a2s-$($preset.buildName)"
if (Test-Path $work) { cmd /c "rmdir /s /q `"$work`"" | Out-Null }

Write-Host "Cloning Apps2Samsung $Apps2SamsungTag ..."
git -c core.longpaths=true -c advice.detachedHead=false clone -q --depth 1 --branch $Apps2SamsungTag `
    https://github.com/Apps2Samsung/Apps2Samsung.git $work
if ($LASTEXITCODE) { throw 'git clone failed.' }

Push-Location $work
try {
    git apply --whitespace=nowarn (Join-Path $root 'apps2samsung-preset.patch')
    if ($LASTEXITCODE) { throw "Patch does not apply to $Apps2SamsungTag." }
} finally { Pop-Location }

Copy-Item (Join-Path $root 'preset.json') (Join-Path $work 'Jellyfin2Samsung-CrossOS\Assets\preset.json')

Write-Host 'Publishing single-file self-contained win-x64 ...'
$publish = Join-Path $work 'publish'
& $Dotnet publish (Join-Path $work 'Jellyfin2Samsung-CrossOS\Apps2Samsung.csproj') `
    -c Release -r win-x64 -o $publish -v quiet `
    -p:SelfContained=true -p:PublishSingleFile=true `
    -p:IncludeAllContentForSelfExtract=true -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=none
if ($LASTEXITCODE) { throw 'dotnet publish failed.' }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$name = "Jellyfin-TV-Installer-$($preset.buildName)"
$exe = Join-Path $dist "$name.exe"
Copy-Item (Join-Path $publish 'Apps2Samsung.exe') $exe -Force

# Zip for handing out: exe + instructions + Apps2Samsung's MIT license and notices.
$stage = Join-Path $work 'stage'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $exe $stage
Copy-Item (Join-Path $root 'README.md') (Join-Path $stage 'README.md')
Copy-Item (Join-Path $work 'LICENSE') (Join-Path $stage 'LICENSE-Apps2Samsung.txt')
Copy-Item (Join-Path $work 'NOTICE.md') (Join-Path $stage 'NOTICE-Apps2Samsung.md')
$zip = Join-Path $dist "$name.zip"
if (Test-Path $zip) { [IO.File]::Delete($zip) }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip

# The .NET build server keeps files in $work open; stop it so the cleanup succeeds.
& $Dotnet build-server shutdown | Out-Null
cmd /c "rmdir /s /q `"$work`"" 2>$null | Out-Null

foreach ($f in $exe, $zip) {
    $i = Get-Item $f
    Write-Host ("Built: {0}  ({1:N1} MB)  SHA256 {2}" -f $i.FullName, ($i.Length / 1MB), (Get-FileHash $f).Hash.ToLower())
}
