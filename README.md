# Auto Push

A lightweight PowerShell utility that automatically detects and pushes git commits when your local branch is ahead of the remote. Runs as a system tray application with pause/resume controls and notifications.

## Features

- **Automatic Detection** — Polls repositories every 5 minutes (configurable) for unpushed commits
- **System Tray Icon** — Green icon when running, gray when paused
- **Pause/Resume** — Right-click menu to pause detection without exiting
- **Notifications** — Toast notifications on successful push or failure
- **Logging** — Tracks push events to a log file (only logs actual pushes, not checks)
- **Multi-Repo** — Monitor multiple repositories from a single config
- **Auto-Start** — Optional startup on Windows login (configurable)
- **Clean Tray** — Runs silently in system tray with no taskbar flashing

## Installation

1. Save these files to `C:\Users\<username>\.local\bin\` (or any directory in your PATH):
   - `autopush.ps1` — Main application
   - `run-autopush.ps1` — Optional launcher script
   - `autopush-config.json` — Configuration file
   - `autopush_running.ico` — Running state icon
   - `autopush_paused.ico` — Paused state icon

2. Edit `autopush-config.json` with your repository paths and preferences

3. **One-time launch:** 
   
   ```powershell
   run-autopush
   ```
   or call directly:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\Users\<username>\.local\bin\autopush.ps1"
   ```
   
4. **Auto-start on login:** Set `"autoStart": true` in config (creates a startup shortcut automatically)

## Configuration

Edit `autopush-config.json`:

```json
{
  "checkInterval": 300,
  "showNotifications": true,
  "autoStart": true,
  "logFile": null,
  "iconRunning": "autopush_running.ico",
  "iconPaused": "autopush_paused.ico",
  "repositories": [
    {
      "path": "C:\\path\\to\\repo",
      "branch": "main",
      "enabled": true
    }
  ]
}
```

**Options:**
- `checkInterval` — Seconds between checks (default: 300 = 5 minutes)
- `showNotifications` — Enable toast notifications (true/false)
- `autoStart` — Create startup shortcut on first run (true/false). Set to false to remove.
- `logFile` — Path to log file; set to null to disable logging. Relative paths resolve to script directory.
- `iconRunning` / `iconPaused` — Icon file names or paths. Relative paths resolve to script directory.
- `repositories` — Array of repos with path, branch, and enabled status. Paths should be absolute. Each branch must have an upstream tracking branch configured (`git push -u origin <branch>`); repos without one are skipped with a warning.

## Usage

### Start
```powershell
run-autopush
```

### Right-Click Menu (System Tray)
- **Pause** — Pause checking (toggles to Resume)
- **Edit Config** — Opens config file in Notepad. Changes take effect on next restart.
- **Exit** — Stop the app

### Logging
Push events are logged to the configured log file with timestamp and result:
```
[2026-04-13 16:45:23] C:\path\to\repo (main): PUSH SUCCESS (3 commit(s))
[2026-04-13 16:50:15] C:\path\to\repo (main): PUSH FAILED (2 commit(s) ahead)
```

## Requirements

- Windows 7+
- PowerShell 5.0+ (or PowerShell 7+)
- Git installed and in PATH
- .NET Framework 4.5+

## Limitations

- Only works on Windows

## License

MIT

