# openclaw-utilities

A small set of utilities for configuring the **OpenClaw Gateway** to start silently on Windows.

This repository currently includes a PowerShell script that:

- Creates a `.openclaw` folder in the current user's profile
- Generates a `gateway_start.vbs` helper script to launch the OpenClaw gateway without a visible console
- Updates the existing OpenClaw scheduled task (if present) to run the VBS helper
- Stops any running gateway PowerShell processes and launches the gateway immediately

---

## ✅ Usage

1. Open an **elevated PowerShell** (Run as Administrator).
2. Run:

```powershell
.\setup_openclaw_silent.ps1
```

The script will:

- Ensure `%USERPROFILE%\.openclaw` exists
- Create `%USERPROFILE%\.openclaw\gateway_start.vbs`
- Update the existing OpenClaw scheduled task to point to the VBS helper
- Stop any currently running gateway PowerShell process
- Launch the gateway immediately (so you don’t need to reboot)

---

## 🛠️ What it configures

### VBS helper (`gateway_start.vbs`)
The VBS file runs `gateway.cmd` silently (no visible console window) by calling it through `wscript.exe`.

### Scheduled Task update
The script searches for any scheduled task with "OpenClaw" (case-insensitive) in the task name or description and updates its action to run the new VBS helper.

---

## 🔍 Troubleshooting

- If the script cannot find an OpenClaw scheduled task, it will print instructions to manually update the task via Task Scheduler (`taskschd.msc`).
- If the script cannot modify the task (permission or other issues), it will print a manual step-by-step guide.

---

## 📄 Files

- `setup_openclaw_silent.ps1` — main helper script (run as Administrator)

---

## 📌 Notes

- This repository is intended for Windows environments.
- Run the script again if you need to reapply the configuration after changes.
