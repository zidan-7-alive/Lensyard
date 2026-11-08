#!/system/bin/sh
ui_print "- Installing Lensyard"
DATA=/data/adb/lensyard
mkdir -p "$DATA"
CFG=$DATA/config
[ -f "$CFG" ] || : > "$CFG"
# Keep the user's settings on updates; only add keys that are missing
add_default() { grep -q "^$1=" "$CFG" || echo "$1=$2" >> "$CFG"; }
add_default INTERVAL 15; add_default MAXKB 1024; add_default HIDE_SYSTEM 0
add_default BAT_SEC 120; add_default HEAT_C 42; add_default AUTO_HEAT 0
add_default NOTIFY 1; add_default NEWAPP 1; add_default DAILY_AT 21
rm -f "$DATA/prev.keys" "$DATA/prev.keys.new" "$DATA/rules.applied"
set_perm_recursive "$MODPATH" 0 0 0755 0755
ui_print "- Done. Reboot, then open the module's WebUI (or press its Action button)."
