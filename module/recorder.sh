#!/system/bin/sh
# Low-power recorder: one awk process stays alive; this loop only sends it a tick.
MODDIR=${0%/*}; [ "$MODDIR" = "$0" ] && MODDIR=.
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
$AWK $AWKOPT -v lf="$LOG" -v pkfile="$PKGLIST" -v hide="$HIDE_SYSTEM" \
  -f "$MODDIR/scan.awk" < "$FIFO" 2>>"$DATA/error.log" &
AWKPID=$!
cleanup() { kill "$AWKPID" 2>/dev/null; rm -f "$FIFO"; exit 0; }
trap cleanup TERM INT HUP
exec 3> "$FIFO"
ME=$(( (60 + INTERVAL - 1) / INTERVAL ))   # run the once-a-minute jobs about every 60 s
n=0
while true; do
  date +%s >&3 || cleanup
  n=$((n + 1))
  [ $((n % 120)) -eq 0 ] && trim
  [ $((n % ME)) -eq 0 ] && sh "$MODDIR/lensyard.sh" minute >/dev/null 2>&1
  sleep "$INTERVAL" &
  wait $!
done
