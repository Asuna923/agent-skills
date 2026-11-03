# Validation — 2026-11-03

Version: 0.1.0. Tested on Windows, Windows PowerShell 5.1 and Python 3.11. The active Codex desktop agent executable reports `codex-cli 0.166.0-alpha.5.1`; the separate npm CLI package manifest is `0.147.0`. The GUI application's own version was not established. Other agent clients were not runtime-tested.

| Area | Result | Scope |
|---|---|---|
| Skill structure | Passed | Bundled skill-creator validator; UTF-8 mode on the Windows locale |
| PowerShell syntax | Passed | AST parsing |
| Offline minimum example | Passed | Synthetic executable: device listing, explicit-serial status, hierarchy parsing with warning prefix/suffix, clickable summary, XML export, binary capture, ASCII spaces |
| Negative cases | Passed | Missing serial/output, output inside the installed skill, shell metacharacters and malformed package rejected |
| Installation | Passed | Selected skill copied to an isolated new destination; all hashes match; existing destination rejected |
| Review | Static inspection | Required files, dependencies, attribution and portable paths reviewed; selected files exclude private runtime artifacts |
| Physical phone | Not verified | No actual phone operated in these release tests |
| IME switching/restoration | Not verified | Optional adb-keyboard-text path not exercised |
| Other clients and discovery | Not verified | No claim that another computer installed or loaded this skill |

The offline suite has 13 assertions. Its C# ADB fixture is synthetic, not a real device. Binary streaming is tested with marker bytes, not a visual screenshot or display selection.

Reproduce from the repository root, selecting a new permitted directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\test-release.ps1 -WorkRoot '<new-permitted-test-directory>'
```

The fixture uses the Windows .NET compiler; compiler temporary files and runtime output are redirected below WorkRoot. It does not connect to a phone or change client configuration. Never add actual UI dumps or screenshots as public fixtures.
