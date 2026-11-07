#!/system/bin/sh
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 30
sh "$MODDIR/whodunit.sh" reapply   # firewall rules don't survive a reboot
sh "$MODDIR/whodunit.sh" start
