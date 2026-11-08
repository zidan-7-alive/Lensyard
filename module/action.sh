#!/system/bin/sh
# Action button: a quick text report (works on every root manager, even without a WebUI).
MODDIR=${0%/*}; [ "$MODDIR" = "$0" ] && MODDIR=.
L="sh $MODDIR/lensyard.sh"
$L start >/dev/null 2>&1
echo "=== LENSYARD $($L version) ==="
$L status
echo
$L batt-kv | while IFS='=' read -r k v; do
  case "$k" in
    level) printf 'Battery: %s%%' "$v" ;;
    temp) [ "$v" != "?" ] && printf '  %s.%sC' "$((v / 10))" "$((v % 10))" ;;
    bstatus) printf '  %s\n' "$v" ;;
  esac
done
echo "Unread alerts: $($L alerts-unread)"
echo
$L who 60 | head -n 8
echo
echo "Open this module's WebUI for the full view."
