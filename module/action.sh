#!/system/bin/sh
MODDIR=${0%/*}
sh "$MODDIR/lensyard.sh" start >/dev/null 2>&1
echo "=== LENSYARD ==="
sh "$MODDIR/lensyard.sh" status
echo
sh "$MODDIR/lensyard.sh" who 60
echo
echo "Open this module's WebUI for the full view."
