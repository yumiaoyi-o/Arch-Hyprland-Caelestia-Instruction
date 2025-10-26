#!/usr/bin/env bash
set -euo pipefail

# migrate_snapshots_common.sh
# Unified script to mount an EMPTY /.snapshots or /home/.snapshots to a btrfs
# subvolume (@snapshots_root or @snapshots_home).
# Supports interactive choice or CLI flags, plus --dry-run and --yes.

usage() {
  cat <<EOF
Usage: sudo $0 [--target root|home] [--subvol NAME] [--dry-run] [--yes]

If --target is omitted the script will prompt interactively.
Default subvol for 'home' is @snapshots_home and for 'root' is @snapshots_root.
--dry-run  : Print actions without modifying fstab or moving directories.
--yes      : Don't ask for confirmation (use carefully).

Example:
  sudo $0 --target home
  sudo $0 --target root --dry-run
EOF
}

TARGET=""
SUBVOL=""
DRY_RUN=0
ASSUME_YES=0

# parse args
while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"; shift 2;;
    --target=*)
      TARGET="${1#*=}"; shift;;
    --subvol)
      SUBVOL="$2"; shift 2;;
    --subvol=*)
      SUBVOL="${1#*=}"; shift;;
    --dry-run)
      DRY_RUN=1; shift;;
    --yes)
      ASSUME_YES=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 3
fi

# Interactive choose if TARGET not provided
if [ -z "$TARGET" ]; then
  echo "Choose migration target:";
  echo "  1) /home/.snapshots -> @snapshots_home";
  echo "  2) /.snapshots -> @snapshots_root";
  read -rp "Select 1 or 2: " choice
  case "$choice" in
    1) TARGET=home;;
    2) TARGET=root;;
    *) echo "Invalid choice"; exit 4;;
  esac
fi

TARGET=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')
if [ "$TARGET" != "home" -a "$TARGET" != "root" ]; then
  echo "--target must be 'home' or 'root'" >&2
  exit 5
fi

# set derived variables
if [ "$TARGET" = "home" ]; then
  DST_DIR="/home/.snapshots"
  DEFAULT_SUBVOL='@snapshots_home'
  FS_MOUNTPOINT='/home'
else
  DST_DIR='/.snapshots'
  DEFAULT_SUBVOL='@snapshots_root'
  FS_MOUNTPOINT='/'
fi

: ${SUBVOL:=$DEFAULT_SUBVOL}

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FSTAB="/etc/fstab.bak.$TIMESTAMP"
BACKUP_SN_DIR="$DST_DIR.bak.$TIMESTAMP"
TMP_MNT="/mnt/$(basename "$DST_DIR")_verify"

# helper to run or print (dry-run)
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ DRY-RUN: $*"
  else
    echo "+ RUN: $*"
    eval "$@"
  fi
}

confirm() {
  if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  read -rp "$1 [y/N]: " ans
  case "$ans" in
    [Yy]*) return 0;;
    *) return 1;;
  esac
}

# 1) find source device for mountpoint
FS_SRC=$(findmnt -no SOURCE "$FS_MOUNTPOINT" || true)
if [ -z "$FS_SRC" ]; then
  echo "Unable to determine source device for $FS_MOUNTPOINT." >&2
  exit 6
fi

echo "$FS_MOUNTPOINT is on: $FS_SRC"

# 2) ensure btrfs
if ! btrfs filesystem show "$FS_SRC" &>/dev/null; then
  echo "Device $FS_SRC doesn't look like btrfs or btrfs tools can't see it." >&2
  exit 7
fi

# 3) check subvolume exists
# Use mountpoint as the listing root when possible
LIST_ROOT="$FS_MOUNTPOINT"
if ! btrfs subvolume list "$LIST_ROOT" 2>/dev/null | grep -q "^.* $SUBVOL$\|@${SUBVOL#@}$\|${SUBVOL#@}$"; then
  # fallback to listing from /
  if ! btrfs subvolume list / 2>/dev/null | grep -q "${SUBVOL}"; then
    echo "Could not find subvolume named '$SUBVOL' in the filesystem." >&2
    exit 8
  fi
fi

# 4) ensure DST_DIR exists and is empty
if [ ! -e "$DST_DIR" ]; then
  echo "$DST_DIR does not exist. Will create it.";
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$DST_DIR"
  fi
fi

if mountpoint -q "$DST_DIR"; then
  echo "$DST_DIR is currently a mountpoint. The script expects it to be an ordinary (empty) directory or not mounted." >&2
  echo "If it's a mounted subvolume you may need to unmount it and handle deletion manually." >&2
fi

# check emptiness
if [ -n "$(ls -A "$DST_DIR" 2>/dev/null || true)" ]; then
  echo "$DST_DIR is not empty. Aborting to avoid data loss." >&2
  exit 9
fi

# 5) verify mounting subvol works
run mkdir -p "$TMP_MNT"
RUN_MOUNT_CMD="mount -o subvol=$SUBVOL $FS_SRC $TMP_MNT"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "+ DRY-RUN would run: $RUN_MOUNT_CMD"
else
  if ! mount -o subvol=$SUBVOL "$FS_SRC" "$TMP_MNT"; then
    echo "Failed to mount subvol=$SUBVOL from $FS_SRC at $TMP_MNT" >&2
    rmdir "$TMP_MNT" 2>/dev/null || true
    exit 10
  fi
  echo "Mounted OK. Contents:"
  ls -la "$TMP_MNT" || true
  umount "$TMP_MNT" || true
fi

# show planned actions and ask confirmation
echo
cat <<EOF
Plan summary:
  Target directory: $DST_DIR
  Subvolume to mount: $SUBVOL (from $FS_SRC)
  fstab backup: $BACKUP_FSTAB
  original dir backup (if exists): $BACKUP_SN_DIR
  dry-run: $DRY_RUN
EOF

if ! confirm "Proceed with these actions?"; then
  echo "Aborted by user."; exit 11
fi

# 6) backup fstab and append line
if [ "$DRY_RUN" -eq 1 ]; then
  echo "+ DRY-RUN: cp -p /etc/fstab $BACKUP_FSTAB"
else
  cp -p /etc/fstab "$BACKUP_FSTAB"
  echo "Backed up /etc/fstab to $BACKUP_FSTAB"
fi

# build fstab device (prefer UUID)
UUID_VAL="$(blkid -s UUID -o value "$FS_SRC" 2>/dev/null || true)"
if [ -n "$UUID_VAL" ]; then
  FSTAB_DEVICE="UUID=$UUID_VAL"
else
  FSTAB_DEVICE="$FS_SRC"
fi
FSTAB_LINE="$FSTAB_DEVICE $DST_DIR btrfs subvol=$SUBVOL,defaults 0 0"

if grep -Fq " $DST_DIR" /etc/fstab; then
  echo "/etc/fstab already contains an entry for $DST_DIR. Skipping fstab append."
else
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ DRY-RUN: append to /etc/fstab: $FSTAB_LINE"
  else
    echo "$FSTAB_LINE" >> /etc/fstab
    echo "Appended fstab line: $FSTAB_LINE"
  fi
fi

# 7) rename existing directory (backup) and create mountpoint
if [ -d "$DST_DIR" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ DRY-RUN: mv $DST_DIR $BACKUP_SN_DIR"
  else
    mv "$DST_DIR" "$BACKUP_SN_DIR"
    echo "Moved $DST_DIR -> $BACKUP_SN_DIR"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "+ DRY-RUN: mkdir -p $DST_DIR"
else
  mkdir -p "$DST_DIR"
fi

# 8) mount all (apply fstab)
if [ "$DRY_RUN" -eq 1 ]; then
  echo "+ DRY-RUN: mount -a"
else
  mount -a
fi

# 9) verify
if [ "$DRY_RUN" -eq 1 ]; then
  echo "+ DRY-RUN: would check mount for $DST_DIR"
  echo "Dry-run complete. Inspect changes (none were made)."
  exit 0
fi

if findmnt -n "$DST_DIR" >/dev/null 2>&1; then
  echo "$DST_DIR successfully mounted from subvol '$SUBVOL'."
  if [ -d "$BACKUP_SN_DIR" ]; then
    echo "Old directory moved to: $BACKUP_SN_DIR"
    echo "If everything looks good you can remove the backup with: sudo rm -rf $BACKUP_SN_DIR"
  fi
else
  echo "Mount failed: check /etc/fstab and logs." >&2
  echo "You can restore previous fstab from $BACKUP_FSTAB if needed." >&2
  exit 12
fi

# cleanup
rmdir "$TMP_MNT" 2>/dev/null || true

echo "Done."
exit 0
