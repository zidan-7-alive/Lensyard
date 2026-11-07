#!/system/bin/sh
# Shared settings and helpers for Lensyard
MODDIR=${MODDIR:-/data/adb/modules/lensyard}
DATA=${DATA:-/data/adb/lensyard}
LOG=$DATA/events.log
INTERVAL=15
MAXKB=1024
HIDE_SYSTEM=0
[ -f "$DATA/config" ] && . "$DATA/config"

find_awk() {
  if command -v awk >/dev/null 2>&1; then echo awk; return; fi
  for b in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /data/adb/ap/bin/busybox /system/xbin/busybox /system/bin/busybox; do
    if [ -x "$b" ]; then echo "$b awk"; return; fi
  done
}
AWK=$(find_awk)

# Keep the newest half of the log when it grows past the size limit
trim() {
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt $((MAXKB * 1024)) ]; then
    tail -c $((MAXKB * 512)) "$LOG" | tail -n +2 > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
  if [ -f "$DATA/error.log" ]; then
    tail -n 50 "$DATA/error.log" > "$DATA/error.tmp" && mv "$DATA/error.tmp" "$DATA/error.log"
  fi
}
