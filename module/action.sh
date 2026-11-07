#!/system/bin/sh
MODDIR=${0%/*}
sh "$MODDIR/whodunit.sh" start >/dev/null 2>&1
echo "=== WHODUNIT ==="
sh "$MODDIR/whodunit.sh" status
echo
sh "$MODDIR/whodunit.sh" who 60
echo
echo "Open this module's WebUI for the full view."
