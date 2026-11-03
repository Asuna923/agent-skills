# Phone ADB agent skill

[phone-adb-control](skills/phone-adb-control/SKILL.md) inspects and operates an authorized Android device through ADB on Windows. It requires an explicitly selected device, and writes runtime artifacts only to a caller-selected location outside the installed skill.

This release contains no phone screenshots, UI dumps, credentials, machine-specific paths, device identifiers, client profiles, private project code or old repository history.

## Requirements

Windows PowerShell 5.1 or PowerShell 7, official Android Platform Tools, and an already authorized ADB device. See the full [SKILL.md](skills/phone-adb-control/SKILL.md) for workflow, commands, side effects and limitations. Installation does not install ADB, device apps or an MCP server, and does not grant USB debugging or action permission.

## Install

Prefer an already installed compatible version. Otherwise review the complete skill and current local permissions, then install only this selected skill.

With a compatible Codex skill-installer, request repository `Asuna923/agent-skills`, path `skills/phone-adb-control`, and pin the reviewed commit. Supply an explicit permitted destination when local storage rules require it.

For manual installation, clone/download this repository at the selected commit into a permitted directory, then run from its root:

```powershell
powershell.exe -NoProfile -File .\tools\install-local.ps1 -Skill phone-adb-control -Destination '<permitted-skill-directory>/phone-adb-control'
```

The installer refuses an existing destination. Read the installed complete `SKILL.md` and reload the client's skill catalog if necessary. A folder-copy test does not prove that another client has loaded or used the skill. Cloud discoverability does not grant execution permission.

## Minimal example

Run from the installed skill directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\phone-adb.ps1 -Action devices
```

Then select an authorized device from that output, and explicitly pass `-Serial '<serial>'` to `status` or other device operations. Use a permitted absolute `-OutFile` for screenshots, XML or summaries. Do not publish these private runtime artifacts.

## Validation and license

[VALIDATION.md](VALIDATION.md) distinguishes tested offline fixture behavior, static inspection and unverified live operations. [PROVENANCE.md](PROVENANCE.md) records attribution. The owner approved MIT publication; [LICENSE](LICENSE) is also included inside the independently installable skill folder. Android Platform Tools remain an external dependency under their own terms.
