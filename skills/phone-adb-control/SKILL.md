---
name: phone-adb-control
description: Inspect and operate an authorized, already ADB-connected Android device from Windows. Use for UI hierarchy summaries, screenshots, taps, swipes and simple ASCII input. Requires explicit device selection; does not install ADB or device apps.
---

# Phone ADB Control

Use `scripts/phone-adb.ps1` for an Android device the user has authorized. Prefer ADB for this workflow when available. Installation supplies instructions and a helper, not USB debugging approval or permission to operate a phone.

## Requirements and scope

- Windows PowerShell 5.1 or PowerShell 7; official Android Platform Tools (`adb`) on PATH or passed with `-AdbPath`.
- USB debugging must already be authorized on the device. Never accept a new debugging trust prompt on the user's behalf.
- Run `-Action devices`, then explicitly pass `-Serial` to every device operation. Never copy a serial from another machine or choose the first device silently.
- For screenshots, XML and summaries, supply `-OutFile` in a user-permitted runtime directory outside this skill. These files may contain private information; do not publish them.

## Workflow

1. Read current user instructions and determine the authorized device/action.
2. Run `devices`, then `status` for the selected device.
3. Prefer `ui-summary -MaxItems 40` for native apps. Use `ui` for hierarchy details, and `screenshot` for layout or image-only UI.
4. Derive bounds and labels from the current device state. Perform one navigation or input action, then inspect again. Do not reuse unverified app coordinates.
5. Simple ASCII text is supported. Shell metacharacters and Unicode are rejected; use the device keyboard for other text. `adb-keyboard-text` additionally requires an already installed `com.android.adbkeyboard/.AdbIME`, temporarily switches the IME, and attempts to restore the previous selection; use only when that change is authorized. It does not install that app.

Messages, submissions, profile changes, payments and deletions require the user's authorization for the actual external action. Prepare drafts freely; before a final send or destructive action, check the applicable current permissions. Do not infer authorization from a visible button or from installing this skill.

## Examples

Run from this skill directory. Replace `<serial>` with the device selected from `devices`; replace `<output>` with a permitted absolute output path.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\phone-adb.ps1 -Action devices
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\phone-adb.ps1 -Action status -Serial '<serial>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\phone-adb.ps1 -Action ui-summary -Serial '<serial>' -OutFile '<output>/ui-summary.txt' -MaxItems 40
```

Other actions: `screenshot`, `ui`, `tap -X ... -Y ...`, `swipe -X ... -Y ... -X2 ... -Y2 ...`, `text -Text ...`, `back`, `home`, `recent`, `launch -Package ...`.

Limitations: secure windows may hide UI or screenshots; multi-display devices can require a display-specific capture not implemented by this helper. Offline fixture tests do not demonstrate real phone operation. See repository `VALIDATION.md` for this release's actual checks.
