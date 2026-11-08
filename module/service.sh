#!/system/bin/sh
MODDIR=${0%/*}; [ "$MODDIR" = "$0" ] && MODDIR=.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 30
sh "$MODDIR/lensyard.sh" reapply   # firewall rules and counters don't survive a reboot
sh "$MODDIR/lensyard.sh" start
