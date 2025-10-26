#!/usr/bin/env bash
# ATrust restart + cleanup helper (no backups)
# Steps: stop service -> list processes -> TERM then KILL -> remove runtime sockets/lockfiles -> start service -> collect logs
# Safe defaults: supports --dry-run and --preserve-tray

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME=$(basename "$0")
DRYRUN=0
PRESERVE_TRAY=0
JOURNAL_LINES=200
SERVICE_NAME=aTrustDaemon.service

usage(){
  cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--preserve-tray] [--lines N]

Options:
  --dry-run        Print the actions but don't execute.
  --preserve-tray  Do not kill processes whose command line contains "aTrustTray".
  --lines N        How many journal lines to show after restart (default: $JOURNAL_LINES).
  --help           Show this help and exit.

This script purposely does NOT create backups. It performs destructive cleanup of runtime sockets/lockfiles.
Run with care. Service stop/start will use sudo when required.
EOF
}

# runner that echoes commands when dry-run
run(){
  if [ "$DRYRUN" -eq 1 ]; then
    echo "+ $*"
  else
    eval "$*"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRYRUN=1; shift;;
    --preserve-tray) PRESERVE_TRAY=1; shift;;
    --lines) shift; JOURNAL_LINES=${1:-$JOURNAL_LINES}; shift;;
    --help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done

echo "[$SCRIPT_NAME] starting"$( [ "$DRYRUN" -eq 1 ] && echo " -- DRY-RUN" )

# 1) Stop service
echo "[1] Stopping $SERVICE_NAME"
run "sudo systemctl stop $SERVICE_NAME || true"

# 2) List processes matching aTrust|sangfor
echo "[2] Listing processes matching 'aTrust' or 'sangfor'"
# Use pgrep -a for readable output
if [ "$DRYRUN" -eq 1 ]; then
  echo "+ pgrep -a -f 'aTrust|sangfor' || true"
else
  pgrep -a -f 'aTrust|sangfor' || true
fi

# Build list of PIDs to terminate (avoid killing this script)
MY_PID=$$
PIDS=$(pgrep -f 'aTrust|sangfor' || true)

if [ -n "$PIDS" ]; then
  # filter out our own pid and optionally aTrustTray
  FILTERED=$(echo "$PIDS" | while read -r pid; do
    [ -z "$pid" ] && continue
    [ "$pid" -eq "$MY_PID" ] && continue
    cmd=$(ps -p "$pid" -o cmd= 2>/dev/null || true)
    if [ "$PRESERVE_TRAY" -eq 1 ] && echo "$cmd" | grep -q "aTrustTray"; then
      continue
    fi
    echo "$pid"
  done || true)

  if [ -n "$FILTERED" ]; then
    echo "[3] Sending SIGTERM to PIDs:\n$FILTERED"
    run "echo \"$FILTERED\" | xargs -r sudo kill -TERM || true"
    sleep 2
    # re-check: test which of the previously targeted PIDs still exist (use kill -0)
    REMAIN=$(echo "$FILTERED" | while read -r _pid; do
      [ -z "$_pid" ] && continue
      if kill -0 "$_pid" 2>/dev/null; then
        echo "$_pid"
      fi
    done || true)
    # Also check for any other matching processes
    STILL=$(pgrep -f 'aTrust|sangfor' || true)
    if [ -n "$STILL" ]; then
      # filter again for preservation
      FORCE=$(echo "$STILL" | while read -r pid; do
        [ -z "$pid" ] && continue
        [ "$pid" -eq "$MY_PID" ] && continue
        cmd=$(ps -p "$pid" -o cmd= 2>/dev/null || true)
        if [ "$PRESERVE_TRAY" -eq 1 ] && echo "$cmd" | grep -q "aTrustTray"; then
          continue
        fi
        echo "$pid"
      done || true)
      if [ -n "$FORCE" ]; then
        echo "[3b] Force-killing remaining PIDs:\n$FORCE"
        run "echo \"$FORCE\" | xargs -r sudo kill -9 || true"
      else
        echo "[3b] No remaining PIDs to force-kill after filter."
      fi
    else
      echo "[3b] No remaining PIDs after SIGTERM."
    fi
  else
    echo "[3] No PIDs to kill after filtering."
  fi
else
  echo "[2] No matching processes found."
fi

# 4) Remove runtime sockets/lockfiles
USR_A=/usr/share/sangfor/.aTrust
USER_A="$HOME/.aTrust"

echo "[4] Removing runtime sockets/lockfiles under $USR_A and $USER_A"
# remove under /usr (sudo)
run "sudo bash -c 'rm -vf \"$USR_A/var/run\"/* 2>/dev/null || true'"
run "sudo bash -c 'rm -vf \"$USR_A\"/*lock* \"$USR_A/sapp-*\" 2>/dev/null || true'"
# remove under $HOME
run "rm -vf \"$USER_A/var/run\"/* 2>/dev/null || true"
run "rm -vf \"$USER_A\"/*lock* \"$USER_A/sapp-*\" 2>/dev/null || true"

# 5) Start service
echo "[5] Starting $SERVICE_NAME"
run "sudo systemctl start $SERVICE_NAME || true"

# 6) Collect recent journal lines for the service
echo "[6] Collecting last $JOURNAL_LINES journal lines for $SERVICE_NAME"
if [ "$DRYRUN" -eq 1 ]; then
  echo "+ sudo journalctl -u $SERVICE_NAME -n $JOURNAL_LINES --no-pager"
else
  sudo journalctl -u $SERVICE_NAME -n $JOURNAL_LINES --no-pager || true
fi

echo "[DONE]"
exit 0
