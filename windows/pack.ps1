<#
.SYNOPSIS
  Builds the release artifacts for ProxyToggle (Windows): a per-user MSI, a
  portable .zip, an optional self-contained .zip, and SHA256SUMS.txt.
.PARAMETER OutDir
  Where the artifacts are written. Defaults to <repo>\dist.
.PARAMETER Version
  Overrides the version. Defaults to <Version> in ProxyToggle.csproj.
.PARAMETER SkipSelfContained
  Skip the (large) bundled-runtime zip.
#>
[CmdletBinding()]
param(
    [string]$OutDir,
    [string]$Version,
    [switch]$SkipSelfContained
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

foreach ($tool in 'dotnet', 'wix') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not found. Need the .NET 8 SDK and 'dotnet tool install --global wix'."
    }
}

$csproj = Join-Path $PSScriptRoot 'ProxyToggle.csproj'
if (-not $Version) {
    $Version = ([regex]::Match((Get-Content -Raw $csproj), '<Version>([^<]+)</Version>')).Groups[1].Value
    if (-not $Version) { throw "Could not read <Version> from $csproj" }
}
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist' }

$staging = Join-Path $PSScriptRoot 'obj\pack'
Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OutDir, "$staging\framework", "$staging\selfcontained" | Out-Null

Get-Process -Name ProxyToggle -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "ProxyToggle $Version" -ForegroundColor Cyan

# --- framework-dependent single exe -----------------------------------------
Write-Host '==> publish (framework-dependent)' -ForegroundColor Cyan
dotnet publish $csproj -c Release -r win-x64 --self-contained false -o "$staging\framework" --nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }
$exe = Join-Path $staging 'framework\ProxyToggle.exe'

# --- MSI ---------------------------------------------------------------------
Write-Host '==> wix build (per-user MSI)' -ForegroundColor Cyan
$msi = Join-Path $OutDir "ProxyToggle-$Version-win-x64.msi"
wix build installer\ProxyToggle.wxs `
    -arch x64 `
    -culture ja-JP `
    -define "Version=$Version" `
    -define "ExeSource=$exe" `
    -ext WixToolset.UI.wixext `
    -ext WixToolset.Util.wixext `
    -o $msi
if ($LASTEXITCODE -ne 0) { throw "wix build failed ($LASTEXITCODE)" }
# wix drops a .wixpdb beside the .msi; it is a build artifact, not a release one.
Move-Item ([IO.Path]::ChangeExtension($msi, '.wixpdb')) "$staging\ProxyToggle.wixpdb" -Force -ErrorAction SilentlyContinue

# --- portable zip ------------------------------------------------------------
Write-Host '==> portable zip' -ForegroundColor Cyan
$zip = Join-Path $OutDir "ProxyToggle-$Version-win-x64-portable.zip"
Copy-Item (Join-Path $PSScriptRoot 'README.md') "$staging\framework\README.md"
Copy-Item (Join-Path (Split-Path $PSScriptRoot -Parent) 'LICENSE') "$staging\framework\LICENSE"
Compress-Archive -Path "$staging\framework\*" -DestinationPath $zip -Force

# --- self-contained zip ------------------------------------------------------
if (-not $SkipSelfContained) {
    Write-Host '==> publish (self-contained)' -ForegroundColor Cyan
    dotnet publish $csproj -c Release -r win-x64 --self-contained true -o "$staging\selfcontained" --nologo -v q
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish (self-contained) failed ($LASTEXITCODE)" }
    Copy-Item (Join-Path $PSScriptRoot 'README.md') "$staging\selfcontained\README.md"
    Copy-Item (Join-Path (Split-Path $PSScriptRoot -Parent) 'LICENSE') "$staging\selfcontained\LICENSE"
    Compress-Archive -Path "$staging\selfcontained\*" `
        -DestinationPath (Join-Path $OutDir "ProxyToggle-$Version-win-x64-selfcontained.zip") -Force
}

# --- checksums ---------------------------------------------------------------
Write-Host '==> checksums' -ForegroundColor Cyan
$sums = Join-Path $OutDir 'SHA256SUMS.txt'
Remove-Item $sums -ErrorAction SilentlyContinue
Get-ChildItem $OutDir -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object Name | ForEach-Object {
    "{0}  {1}" -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name
} | Set-Content -Path $sums -Encoding ascii

Write-Host ''
Get-ChildItem $OutDir -File | Select-Object Name, @{n = 'Size'; e = { '{0:N0} KB' -f ($_.Length / 1KB) } } | Format-Table -AutoSize
Write-Host "artifacts: $OutDir" -ForegroundColor Green
