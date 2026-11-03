[CmdletBinding()]
param(
    [ValidateSet('devices', 'status', 'screenshot', 'ui', 'ui-summary', 'tap', 'swipe', 'text', 'adb-keyboard-text', 'back', 'home', 'recent', 'launch')]
    [string]$Action = 'status',
    [string]$Serial = '',
    [string]$AdbPath = 'adb',
    [Nullable[int]]$X,
    [Nullable[int]]$Y,
    [Nullable[int]]$X2,
    [Nullable[int]]$Y2,
    [ValidateRange(50, 10000)]
    [int]$DurationMs = 300,
    [string]$Text,
    [string]$Package,
    [string]$OutFile,
    [ValidateRange(1, 200)]
    [int]$MaxItems = 60,
    [switch]$ClickableOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$adbCommand = Get-Command $AdbPath -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $adbCommand) { throw 'ADB executable not found. Install official Android Platform Tools and pass -AdbPath or configure PATH.' }
$AdbPath = $adbCommand.Source
if ($Serial -and $Serial -notmatch '^[A-Za-z0-9_.:-]+$') { throw 'Invalid ADB serial.' }
if ($Action -ne 'devices' -and [string]::IsNullOrWhiteSpace($Serial)) {
    throw '-Serial is required for device operations. Run -Action devices, then select an authorized device explicitly.'
}
if ($Action -in @('screenshot', 'ui', 'ui-summary')) {
    if ([string]::IsNullOrWhiteSpace($OutFile)) { throw '-OutFile is required; choose a writable output location outside the installed skill.' }
    $OutFile = [System.IO.Path]::GetFullPath($OutFile)
    $installedRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\') + '\'
    if ($OutFile.StartsWith($installedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Runtime output must be outside the installed skill directory.'
    }
}
if ($Action -eq 'launch' -and $Package -notmatch '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$') { throw 'Invalid Android package name.' }
if ($Action -in @('text', 'adb-keyboard-text') -and $Text -notmatch '^[A-Za-z0-9 .,!?_:@/+\-=]+$') {
    throw 'This helper only injects simple ASCII text; shell metacharacters and Unicode require the device keyboard.'
}

function Get-AdbPrefix {
    if ([string]::IsNullOrWhiteSpace($Serial)) {
        return @()
    }

    return @('-s', $Serial)
}

function Invoke-Adb {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $allArguments = @(Get-AdbPrefix) + $Arguments
    $result = & $AdbPath @allArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("adb failed ({0}): {1}" -f $LASTEXITCODE, ($result -join [Environment]::NewLine))
    }

    return $result
}

function Require-Coordinates {
    param([string[]]$Names)

    foreach ($name in $Names) {
        if ($null -eq (Get-Variable -Name $name -ValueOnly)) {
            throw "-$name is required for Action '$Action'."
        }
    }
}

function Save-AdbBinaryOutput {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Path
    )

    $allArguments = @(Get-AdbPrefix) + $Arguments
    $quotedArguments = $allArguments | ForEach-Object {
        '"' + ($_ -replace '"', '\\"') + '"'
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $AdbPath
    $processInfo.Arguments = $quotedArguments -join ' '
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    [void]$process.Start()

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $file = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $process.StandardOutput.BaseStream.CopyTo($file)
    }
    finally {
        $file.Dispose()
    }

    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "adb failed ($($process.ExitCode)): $standardError"
    }
}

function Get-UiHierarchyXml {
    $rawXml = (Invoke-Adb @('exec-out', 'uiautomator', 'dump', '/dev/tty')) -join [Environment]::NewLine
    $closingTag = '</hierarchy>'
    $closingIndex = $rawXml.IndexOf($closingTag, [System.StringComparison]::Ordinal)
    if ($closingIndex -lt 0) { throw 'uiautomator did not return a valid hierarchy document.' }
    $startIndex = $rawXml.IndexOf('<hierarchy', [System.StringComparison]::Ordinal)
    if ($startIndex -lt 0 -or $startIndex -gt $closingIndex) { throw 'uiautomator did not return a hierarchy root.' }
    return $rawXml.Substring($startIndex, $closingIndex + $closingTag.Length - $startIndex)
}

switch ($Action) {
    'devices' {
        # Do not use -s here so every attached device is visible.
        & $AdbPath devices -l
        if ($LASTEXITCODE -ne 0) { throw "adb devices failed ($LASTEXITCODE)." }
    }
    'status' {
        Write-Output ('Serial: ' + $Serial)
        Write-Output ('State: ' + (Invoke-Adb @('get-state')))
        Write-Output ('Display: ' + (Invoke-Adb @('shell', 'wm', 'size')))
        Write-Output ('Battery: ' + (Invoke-Adb @('shell', 'dumpsys', 'battery') | Select-String -Pattern 'level|status' | ForEach-Object { $_.ToString().Trim() }))
    }
    'screenshot' {
        if ([string]::IsNullOrWhiteSpace($OutFile)) {
            throw '-OutFile is required.'
        }
        Save-AdbBinaryOutput -Arguments @('exec-out', 'screencap', '-p') -Path $OutFile
        Write-Output "Screenshot saved: $OutFile"
    }
    'ui' {
        if ([string]::IsNullOrWhiteSpace($OutFile)) {
            throw '-OutFile is required.'
        }
        $xml = Get-UiHierarchyXml
        $directory = Split-Path -Parent $OutFile
        if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
        [System.IO.File]::WriteAllText($OutFile, $xml, [System.Text.UTF8Encoding]::new($false))
        Write-Output "UI dump saved: $OutFile"
    }
    'ui-summary' {
        if ([string]::IsNullOrWhiteSpace($OutFile)) {
            throw '-OutFile is required.'
        }
        [xml]$document = Get-UiHierarchyXml
        $seen = New-Object 'System.Collections.Generic.HashSet[string]'
        $summary = New-Object 'System.Collections.Generic.List[string]'

        foreach ($node in $document.SelectNodes('//node')) {
            $label = $node.GetAttribute('text')
            if ([string]::IsNullOrWhiteSpace($label)) { $label = $node.GetAttribute('content-desc') }
            if ([string]::IsNullOrWhiteSpace($label)) { $label = $node.GetAttribute('hint') }
            if ([string]::IsNullOrWhiteSpace($label)) { continue }
            if ($ClickableOnly -and $node.GetAttribute('clickable') -ne 'true') { continue }

            $kind = if ($node.GetAttribute('clickable') -eq 'true') { 'tap' } else { 'text' }
            $line = '{0} {1} {2}' -f $node.GetAttribute('bounds'), $kind, ($label -replace '\s+', ' ')
            if ($seen.Add($line)) { [void]$summary.Add($line) }
            if ($summary.Count -ge $MaxItems) { break }
        }

        $directory = Split-Path -Parent $OutFile
        if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
        [System.IO.File]::WriteAllLines($OutFile, $summary, [System.Text.UTF8Encoding]::new($false))
        Write-Output "UI summary saved: $OutFile ($($summary.Count) items)"
    }
    'tap' {
        Require-Coordinates @('X', 'Y')
        Invoke-Adb @('shell', 'input', 'tap', $X, $Y) | Out-Null
    }
    'swipe' {
        Require-Coordinates @('X', 'Y', 'X2', 'Y2')
        Invoke-Adb @('shell', 'input', 'swipe', $X, $Y, $X2, $Y2, $DurationMs) | Out-Null
    }
    'text' {
        if ([string]::IsNullOrWhiteSpace($Text)) { throw '-Text is required for Action text.' }
        if ($Text -notmatch '^[\x20-\x7E]+$') {
            throw 'Action text currently supports ASCII input only. For Chinese text, use the phone keyboard.'
        }
        $inputText = $Text -replace ' ', '%s'
        Invoke-Adb @('shell', 'input', 'text', $inputText) | Out-Null
    }
    'adb-keyboard-text' {
        if ([string]::IsNullOrWhiteSpace($Text)) { throw '-Text is required for Action adb-keyboard-text.' }

        $adbKeyboardIme = 'com.android.adbkeyboard/.AdbIME'
        $inputText = $Text -replace "`r`n|`n|`r", ' '
        $previousIme = (Invoke-Adb @('shell', 'settings', 'get', 'secure', 'default_input_method') | Select-Object -First 1).Trim()

        Invoke-Adb @('shell', 'ime', 'enable', $adbKeyboardIme) | Out-Null
        Invoke-Adb @('shell', 'ime', 'set', $adbKeyboardIme) | Out-Null
        try {
            Invoke-Adb @('shell', 'am', 'broadcast', '-a', 'ADB_INPUT_TEXT', '--es', 'msg', $inputText) | Out-Null
        }
        finally {
            if (-not [string]::IsNullOrWhiteSpace($previousIme) -and $previousIme -ne $adbKeyboardIme) {
                Invoke-Adb @('shell', 'ime', 'set', $previousIme) | Out-Null
            }
        }
    }
    'back' { Invoke-Adb @('shell', 'input', 'keyevent', '4') | Out-Null }
    'home' { Invoke-Adb @('shell', 'input', 'keyevent', '3') | Out-Null }
    'recent' { Invoke-Adb @('shell', 'input', 'keyevent', '187') | Out-Null }
    'launch' {
        if ([string]::IsNullOrWhiteSpace($Package)) { throw '-Package is required for Action launch.' }
        Invoke-Adb @('shell', 'monkey', '-p', $Package, '-c', 'android.intent.category.LAUNCHER', '1') | Out-Null
    }
}
