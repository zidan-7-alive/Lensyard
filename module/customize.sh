#!/system/bin/sh
ui_print "- Installing Whodunit"
DATA=/data/adb/whodunit
mkdir -p "$DATA"
# Fresh low-power defaults (older versions scanned more often and ran warmer)
printf 'INTERVAL=15\nMAXKB=1024\nHIDE_SYSTEM=0\n' > "$DATA/config"
rm -f "$DATA/prev.keys" "$DATA/prev.keys.new"
set_perm_recursive "$MODPATH" 0 0 0755 0755
ui_print "- Done. Reboot, then open the module's WebUI (or press its Action button)."
