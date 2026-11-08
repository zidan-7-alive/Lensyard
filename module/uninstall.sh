#!/system/bin/sh
# Undo everything the module changed outside its own folder, then remove its data.
M=/data/adb/modules/lensyard
[ -f "$M/lensyard.sh" ] && sh "$M/lensyard.sh" restore-all >/dev/null 2>&1
PID=$(cat /data/adb/lensyard/pid 2>/dev/null)
[ -n "$PID" ] && kill "$PID" 2>/dev/null
for T in iptables ip6tables; do
  for c in lensyard_out lensyard_rules lensyard_acct; do
    $T -w -D OUTPUT -j $c 2>/dev/null; $T -w -F $c 2>/dev/null; $T -w -X $c 2>/dev/null
  done
done
rm -rf /data/adb/lensyard
