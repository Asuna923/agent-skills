[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkRoot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$work = [System.IO.Path]::GetFullPath($WorkRoot)
if (Test-Path -LiteralPath $work) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $work | Out-Null
$env:TEMP = Join-Path $work 'temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Path $env:TEMP | Out-Null
$env:PYTHONDONTWRITEBYTECODE = '1'
$fake = Join-Path $work 'fixture-adb.exe'
$code = @'
using System;
using System.IO;
public class FixtureAdb {
    public static int Main(string[] args) {
        string cmd = string.Join(" ", args);
        string log = Environment.GetEnvironmentVariable("SKILL_FIXTURE_LOG");
        if (!string.IsNullOrEmpty(log)) File.AppendAllText(log, cmd + "\n");
        if (cmd == "devices -l") { Console.WriteLine("List of devices attached\nfixture-device device product:synthetic"); return 0; }
        if (!cmd.StartsWith("-s fixture-device ")) return 7;
        if (cmd.EndsWith("get-state")) Console.WriteLine("device");
        else if (cmd.EndsWith("shell wm size")) Console.WriteLine("Physical size: 1080x1920");
        else if (cmd.EndsWith("shell dumpsys battery")) Console.WriteLine("level: 75\nstatus: 2");
        else if (cmd.EndsWith("exec-out uiautomator dump /dev/tty")) Console.WriteLine("synthetic warning\n<?xml version=\"1.0\"?><hierarchy><node text=\"Fixture label\" clickable=\"true\" bounds=\"[1,2][3,4]\"/><node text=\"\" content-desc=\"Second label\" clickable=\"false\" bounds=\"[5,6][7,8]\"/></hierarchy>\nUI hierarchy dumped");
        else if (cmd.EndsWith("exec-out screencap -p")) { byte[] b = new byte[]{137,80,78,71,13,10,26,10,0,255}; Console.OpenStandardOutput().Write(b,0,b.Length); }
        else if (cmd.Contains("shell input text ")) { }
        else return 8;
        return 0;
    }
}
'@
Add-Type -TypeDefinition $code -OutputAssembly $fake -OutputType ConsoleApplication
$env:SKILL_FIXTURE_LOG = Join-Path $work 'fixture-calls.txt'
$helper = Join-Path $repo 'skills\phone-adb-control\scripts\phone-adb.ps1'
$checks = New-Object System.Collections.Generic.List[string]
function Assert-True([bool]$Value, [string]$Name) {
    if (-not $Value) { throw ('FAILED: ' + $Name) }
    $checks.Add($Name)
}
$devices = & $helper -Action devices -AdbPath $fake | Out-String
Assert-True ($devices.Contains('fixture-device')) 'ADB device listing through executable fixture'
$status = & $helper -Action status -AdbPath $fake -Serial fixture-device | Out-String
Assert-True ($status.Contains('1080x1920') -and $status.Contains('75')) 'Selected-device status'
$summary = Join-Path $work 'summary.txt'
& $helper -Action ui-summary -AdbPath $fake -Serial fixture-device -OutFile $summary -ClickableOnly | Out-Null
$summaryText = Get-Content -LiteralPath $summary -Raw
Assert-True ($summaryText.Contains('Fixture label') -and -not $summaryText.Contains('Second label')) 'UI prefix/suffix cleanup and clickable summary filtering'
$xmlPath = Join-Path $work 'ui.xml'
& $helper -Action ui -AdbPath $fake -Serial fixture-device -OutFile $xmlPath | Out-Null
[xml]$xml = Get-Content -LiteralPath $xmlPath -Raw
Assert-True ($xml.hierarchy.node.Count -eq 2) 'Hierarchy XML export'
$pngPath = Join-Path $work 'screen.bin'
& $helper -Action screenshot -AdbPath $fake -Serial fixture-device -OutFile $pngPath | Out-Null
$bytes = [System.IO.File]::ReadAllBytes($pngPath)
Assert-True ($bytes.Length -eq 10 -and $bytes[0] -eq 137 -and $bytes[9] -eq 255) 'Binary screenshot stream preserved'
& $helper -Action text -AdbPath $fake -Serial fixture-device -Text 'Hello world' | Out-Null
Assert-True ((Get-Content -LiteralPath $env:SKILL_FIXTURE_LOG -Raw).Contains('Hello%sworld')) 'ASCII space encoding'
foreach ($case in @('missing-serial','missing-output','installed-output','shell-text','package')) {
    $rejected = $false
    try {
        switch ($case) {
            'missing-serial' { & $helper -Action status -AdbPath $fake }
            'missing-output' { & $helper -Action ui -AdbPath $fake -Serial fixture-device }
            'installed-output' { & $helper -Action ui -AdbPath $fake -Serial fixture-device -OutFile (Join-Path (Split-Path -Parent $helper) 'private.xml') }
            'shell-text' { & $helper -Action text -AdbPath $fake -Serial fixture-device -Text 'hello;echo unwanted' }
            'package' { & $helper -Action launch -AdbPath $fake -Serial fixture-device -Package 'bad;package' }
        }
    } catch { $rejected = $true }
    Assert-True $rejected ('Reject ' + $case)
}
$install = Join-Path $PSScriptRoot 'install-local.ps1'
foreach ($skill in @('phone-adb-control')) {
    $dest = Join-Path (Join-Path $work 'installed') $skill
    & $install -Skill $skill -Destination $dest | Out-Null
    $source = Join-Path (Join-Path $repo 'skills') $skill
    $mismatch = @(Get-ChildItem -LiteralPath $source -File -Recurse | Where-Object {
        $relative = $_.FullName.Substring($source.Length + 1)
        $target = Join-Path $dest $relative
        -not (Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $_.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash
    })
    Assert-True ($mismatch.Count -eq 0) ('Full install hashes: ' + $skill)
    $rejected = $false
    try { & $install -Skill $skill -Destination $dest } catch { $rejected = $true }
    Assert-True $rejected ('Existing installation protected: ' + $skill)
}
$result = [ordered]@{ passed = $true; fixture_only = $true; checks = @($checks); limits = 'No physical phone, firmware build, flashing, live dependency download, or agent discovery tested.' }
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $work 'result.json') -Encoding UTF8
$result | ConvertTo-Json -Depth 5
