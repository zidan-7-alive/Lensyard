#!/system/bin/sh
PID=$(cat /data/adb/lensyard/pid 2>/dev/null)
[ -n "$PID" ] && kill "$PID" 2>/dev/null
rm -rf /data/adb/lensyard
