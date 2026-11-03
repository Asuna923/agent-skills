[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('phone-adb-control')][string]$Skill,
    [Parameter(Mandatory)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path (Join-Path $repoRoot 'skills') $Skill
$destinationFull = [System.IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationFull) { throw 'Destination exists; refusing to overwrite an installed skill.' }
if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) { throw 'Skill manifest missing.' }
$parent = Split-Path -Parent $destinationFull
New-Item -ItemType Directory -Force -Path $parent | Out-Null
Copy-Item -LiteralPath $source -Destination $destinationFull -Recurse
Write-Output ('Installed selected skill: ' + $Skill)
