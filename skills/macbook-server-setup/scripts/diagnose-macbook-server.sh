#!/bin/sh
set -u

section() {
  printf '\n== %s ==\n' "$1"
}

section "Power Source"
pmset -g batt 2>&1 || true

section "Power Settings"
pmset -g 2>&1 || true
pmset -g custom 2>&1 || true

section "Assertions"
pmset -g assertions 2>&1 || true

section "Recent Sleep/Wake Events"
if command -v rg >/dev/null 2>&1; then
  pmset -g log 2>&1 | rg "Entering Sleep|Wake |DarkWake|Using Batt|Using AC|Clamshell|Lid" | tail -80 || true
else
  pmset -g log 2>&1 | grep -Ei "Entering Sleep|Wake |DarkWake|Using Batt|Using AC|Clamshell|Lid" | tail -80 || true
fi

section "Remote Access Ports"
lsof -nP -iTCP:22 -sTCP:LISTEN 2>&1 || true
lsof -nP -iTCP:5900 2>&1 || true

section "IPv4 Addresses"
ifconfig 2>&1 | awk '/^[a-z0-9]+:/{iface=$1; sub(":", "", iface)} /inet / && $2 != "127.0.0.1"{print iface, $2}' || true

section "Server Caffeinate LaunchDaemon"
launchctl print system/com.local.server-caffeinate 2>&1 || true
