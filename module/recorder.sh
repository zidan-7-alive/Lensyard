#!/system/bin/sh
# Low-power recorder: one awk process stays alive; this loop only sends it a tick.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
mkdir -p "$DATA"
if [ -z "$AWK" ]; then echo "no awk found" > "$DATA/error.log"; exit 1; fi
echo $$ > "$DATA/pid"
FIFO=$DATA/tick
rm -f "$FIFO"
mkfifo "$FIFO" || exit 1
# mawk buffers piped input unless told otherwise; other awks stream line by line
AWKOPT=""
case "$($AWK -W version 2>&1 < /dev/null)" in *mawk*) AWKOPT="-W interactive" ;; esac
$AWK $AWKOPT -v lf="$LOG" -v pkfile=/data/system/packages.list -v hide="$HIDE_SYSTEM" \
  -f "$MODDIR/scan.awk" < "$FIFO" 2>>"$DATA/error.log" &
AWKPID=$!
cleanup() { kill "$AWKPID" 2>/dev/null; rm -f "$FIFO"; exit 0; }
trap cleanup TERM INT HUP
exec 3> "$FIFO"
n=0
while true; do
  date +%s >&3 || cleanup
  n=$((n + 1))
  [ $((n % 120)) -eq 0 ] && trim
  sleep "$INTERVAL" &
  wait $!
done
