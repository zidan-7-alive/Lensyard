#!/system/bin/sh
# Shared settings and helpers. Sourced by every other script.
MODDIR=${MODDIR:-/data/adb/modules/lensyard}
DATA=${DATA:-/data/adb/lensyard}
LOG=$DATA/events.log
PKGLIST=${PKGLIST:-/data/system/packages.list}
SYS=${SYS:-/sys/class/power_supply/battery}
EXPORT_DIR=${EXPORT_DIR:-/sdcard/Download}
# ---- defaults (overridden by $DATA/config) ----
INTERVAL=15      # seconds between connection scans
MAXKB=1024       # event log size limit
HIDE_SYSTEM=0    # hide low-level system uids
BAT_SEC=120      # battery / wakelock sampling seconds (0 = off)
HEAT_C=42        # heat alert threshold, degrees C
AUTO_HEAT=0      # 1 = limit the busiest app automatically when hot
NOTIFY=1         # 1 = post system notifications for alerts
NEWAPP=1         # 1 = alert when an app uses the network for the first time
DAILY_AT=21      # hour (0-23) for the daily report, 99 = off
[ -f "$DATA/config" ] && . "$DATA/config"

find_awk() {
  if command -v awk >/dev/null 2>&1; then echo awk; return; fi
  for b in /data/adb/ksu/bin/busybox /data/adb/magisk/busybox /data/adb/ap/bin/busybox /system/xbin/busybox /system/bin/busybox; do
    if [ -x "$b" ]; then echo "$b awk"; return; fi
  done
}
AWK=$(find_awk)

trim_file() {   # keep the newest N lines
  [ -f "$DATA/$1" ] && [ "$(wc -l < "$DATA/$1")" -gt "$2" ] && { tail -n "$2" "$DATA/$1" > "$DATA/$1.tmp" && mv "$DATA/$1.tmp" "$DATA/$1"; }
  return 0
}
# Keep the newest half of the event log once it passes the size limit
trim() {
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt $((MAXKB * 1024)) ]; then
    tail -c $((MAXKB * 512)) "$LOG" | tail -n +2 > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
  trim_file battery.log 4000; trim_file wake.log 6000; trim_file alerts.log 300; trim_file error.log 50
}
