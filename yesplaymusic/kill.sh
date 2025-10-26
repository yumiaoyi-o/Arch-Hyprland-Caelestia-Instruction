#!/bin/sh
# Simple kill script: only terminate YesPlayMusic-related processes for current user
LOG="/tmp/yesplaymusic-desktop-kill.log"
exec >>"$LOG" 2>&1 || true
set -u

echo "------------------------------------------------------------"
echo "[${USER:-unknown}] $(date) - yesplaymusic-kill.sh started (uid=$(id -u))"

USER_UID=$(id -u)
# Try to find pids for known patterns (app.asar, /usr/bin/yesplaymusic, electron binary, or any process named yesplaymusic)
PIDS=""
if command -v pgrep >/dev/null 2>&1; then
  PIDS="$(pgrep -u "$USER_UID" -f "/usr/lib/yesplaymusic/app.asar" 2>/dev/null || true) $(pgrep -u "$USER_UID" -f "/usr/bin/yesplaymusic" 2>/dev/null || true) $(pgrep -u "$USER_UID" -f "electron13" 2>/dev/null || true) $(pgrep -u "$USER_UID" -f "electron" 2>/dev/null || true) $(pgrep -u "$USER_UID" -f "yesplaymusic" 2>/dev/null || true)"
else
  PIDS="$(ps -u "$USER_UID" -o pid= -o args= | awk '/yesplaymusic|app.asar|electron/ {print $1}' || true)"
fi

# normalize whitespace
PIDS="$(echo $PIDS)"

# remove our own pid from the list to avoid killing the script itself
SAFE_PIDS=""
for p in $PIDS; do
  [ -z "$p" ] && continue
  if [ "$p" -eq "$$" ] 2>/dev/null; then
    echo "filtering out self pid $p"
    continue
  fi
  SAFE_PIDS="$SAFE_PIDS $p"
done

PIDS="$(echo $SAFE_PIDS)"

if [ -n "$PIDS" ]; then
  for p in $PIDS; do
    [ -z "$p" ] && continue
    echo "kill -TERM $p"
    kill -TERM "$p" 2>/dev/null || true
  done
  sleep 1
  for p in $PIDS; do
    [ -z "$p" ] && continue
    if kill -0 "$p" 2>/dev/null; then
      echo "kill -KILL $p"
      kill -KILL "$p" 2>/dev/null || true
    fi
  done
else
  echo "no matching processes"
fi

echo "$(date) - yesplaymusic-kill.sh finished"
