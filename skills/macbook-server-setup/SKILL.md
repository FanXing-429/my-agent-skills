---
name: macbook-server-setup
description: Configure a MacBook to behave like a low-power macOS server, especially when the user wants it reachable while idle or lid-closed. Use for macOS power management, preventing sleep with pmset/caffeinate, diagnosing real sleep versus display/VNC blanking, enabling SSH, configuring Screen Sharing/VNC from Windows clients such as TightVNC, and creating or restoring LaunchDaemon-based keep-awake setups.
---

# MacBook Server Setup

## Overview

Use this skill when turning a MacBook into a small always-on server. Prefer conservative, reversible changes: keep the machine on AC power, reduce display/power waste, preserve network access, and verify behavior from logs instead of guessing.

## Workflow

1. Diagnose current state before changing settings.
2. Apply AC-power server settings with `pmset`.
3. Add a system-level `caffeinate` LaunchDaemon when idle/lid behavior must be reliable.
4. Configure remote access: SSH for command-line, Screen Sharing/VNC for desktop.
5. Validate with `pmset -g assertions`, `pmset -g log`, and network reachability.
6. Explain limits: low battery, thermal protection, FileVault login, and lid-closed graphics/VNC behavior can still affect availability.

## Diagnostics

Run `scripts/diagnose-macbook-server.sh` first when possible. It is read-only and reports:

- current power source and battery state
- `pmset` settings and sleep assertions
- recent sleep/wake log entries
- VNC/SSH listening state
- active IPv4 addresses
- the system LaunchDaemon status if present

If the script is unavailable, use these commands directly:

```bash
pmset -g
pmset -g custom
pmset -g assertions
pmset -g batt
pmset -g log | rg "Entering Sleep|Wake |DarkWake|Using Batt|Using AC|Clamshell|Lid"
lsof -nP -iTCP:22 -sTCP:LISTEN
lsof -nP -iTCP:5900
```

Interpretation:

- `SleepDisabled = 1`, AC `sleep = 0`, and `PreventSystemSleep = 1` mean the system is currently protected from normal sleep.
- Recent `Entering Sleep ... Using Batt` means the Mac slept while on battery, often before AC power was connected or after power was lost.
- No recent `Entering Sleep` after AC connection suggests the user may be seeing display sleep, VNC black screen, or a graphics-session issue rather than system sleep.
- If ping/SSH still works while VNC is black, treat it as a VNC/display problem, not system sleep.

## Server Power Settings

For AC-powered server use, apply:

```bash
sudo pmset -a disablesleep 1 sleep 0 standby 0 powernap 0 tcpkeepalive 1 womp 1 ttyskeepawake 1
sudo pmset -c lowpowermode 1 displaysleep 2 disksleep 10
```

Use administrator approval. In the Codex desktop app, `osascript ... with administrator privileges` can show a macOS authorization dialog when interactive sudo is awkward.

These choices mean:

- `disablesleep 1` and `sleep 0`: prevent normal system sleep.
- `standby 0`: reduce deep idle transitions that can break server availability.
- `lowpowermode 1`: reduce power use on AC.
- `displaysleep 2`: let the screen turn off quickly.
- `powernap 0`: reduce maintenance activity.
- `tcpkeepalive 1`, `womp 1`, `ttyskeepawake 1`: preserve network/session behavior useful for servers.

## System Caffeinate Daemon

Use a system LaunchDaemon when user-level `caffeinate` is not reliable enough, especially across lock screen, logout, VNC reconnects, or lid-closed use.

Create `/Library/LaunchDaemons/com.local.server-caffeinate.plist` owned by `root:wheel`, mode `644`, with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.server-caffeinate</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-s</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
```

Load and verify:

```bash
sudo launchctl bootstrap system /Library/LaunchDaemons/com.local.server-caffeinate.plist
sudo launchctl kickstart -k system/com.local.server-caffeinate
launchctl print system/com.local.server-caffeinate
pmset -g assertions
```

Expected validation:

- `state = running`
- `/usr/bin/caffeinate -s`
- `PreventSystemSleep = 1`
- `pid ... caffeinate ... PreventSystemSleep`

Prefer `caffeinate -s` for low-power server mode: it prevents system sleep on AC power without forcing display wakefulness. Avoid `-d` unless the user explicitly wants the display kept awake.

## Remote Access

For SSH:

```bash
sudo systemsetup -getremotelogin
sudo systemsetup -setremotelogin on
lsof -nP -iTCP:22 -sTCP:LISTEN
```

For Windows VNC with TightVNC:

1. Open macOS `System Settings` -> `General` -> `Sharing`.
2. Enable `Screen Sharing`.
3. In details, allow the intended user.
4. In `Computer Settings...`, enable VNC viewers to control the screen with a password.
5. On Windows, connect to `MAC_IP:5900`.

If VNC connects but cannot control:

- Check TightVNC `View only` is off.
- Confirm the macOS Screen Sharing user can control, not only observe.
- Reset the VNC control password.
- Log in locally once if FileVault/login-window behavior is blocking control.

If VNC is slow:

- Use Tight encoding, 8-bit/256-color mode, JPEG compression, and lower JPEG quality.
- Lower macOS display resolution.
- Prefer Ethernet or 5 GHz Wi-Fi.
- Recommend NoMachine/RustDesk when the user needs a smoother desktop than macOS VNC compatibility mode provides.

## Lid-Closed Caveats

macOS can keep the CPU/network alive while lid-closed, but VNC may still show black screen or become awkward without an active display target. If ping/SSH works but VNC is black, recommend:

- keep the lid slightly open, or
- attach an external monitor, or
- use a USB-C/HDMI display emulator, or
- use a remote desktop product that handles virtual display sessions better.

Always keep the MacBook connected to AC and physically ventilated. Do not promise prevention of thermal shutdown, forced low-battery sleep, kernel panic, or firmware-level safety behavior.

## Restore

To remove the server keep-awake daemon:

```bash
sudo launchctl bootout system/com.local.server-caffeinate
sudo rm /Library/LaunchDaemons/com.local.server-caffeinate.plist
```

To restore normal power behavior:

```bash
sudo pmset -a disablesleep 0 standby 1 powernap 1
sudo pmset -c sleep 1 displaysleep 10 disksleep 10 lowpowermode 0
```
