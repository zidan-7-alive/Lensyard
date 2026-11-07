#!/system/bin/sh
PID=$(cat /data/adb/whodunit/pid 2>/dev/null)
[ -n "$PID" ] && kill "$PID" 2>/dev/null
rm -rf /data/adb/whodunit
