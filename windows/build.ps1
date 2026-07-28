<#
.SYNOPSIS
  Builds ProxyToggle.exe and installs it under %LOCALAPPDATA%\Programs\ProxyToggle.
.PARAMETER Dest
  Install directory. Defaults to %LOCALAPPDATA%\Programs\ProxyToggle.
.PARAMETER SelfContained
  Bundle the .NET runtime so the machine does not need the .NET Desktop Runtime
  installed (much larger output).
.PARAMETER Run
  Launch the app once the build finishes.
#>
[CmdletBinding()]
param(
    [string]$Dest = "$env:LOCALAPPDATA\Programs\ProxyToggle",
    [switch]$SelfContained,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "dotnet not found. Install the .NET 8 SDK: https://dotnet.microsoft.com/download"
}

# Stop a running instance so the .exe is not locked.
Get-Process -Name ProxyToggle -ErrorAction SilentlyContinue | Stop-Process -Force

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

dotnet publish ProxyToggle.csproj `
    -c Release `
    -r win-x64 `
    --self-contained $($SelfContained.IsPresent.ToString().ToLower()) `
    -o $Dest
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE" }

$exe = Join-Path $Dest 'ProxyToggle.exe'
Write-Host "built: $exe" -ForegroundColor Green

if ($Run) { Start-Process -FilePath $exe }
