#!/system/bin/sh
# Lensyard control script. Used by the WebUI, the action button and the optional terminal command.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
mkdir -p "$DATA"
BL_FILE=$DATA/blocked.list
FZ_FILE=$DATA/frozen.list
touch "$BL_FILE" "$FZ_FILE"
LM_FILE=$DATA/limited.list
touch "$LM_FILE"
TAB=$(printf '\t')

valid_pkg() { case "$1" in ""|*[!A-Za-z0-9._]*) return 1 ;; esac; return 0; }
list_add() { grep -qx "$2" "$1" 2>/dev/null || echo "$2" >> "$1"; }
list_del() { grep -vx "$2" "$1" > "$1.tmp" 2>/dev/null; mv "$1.tmp" "$1"; }
is_running() { PID=$(cat "$DATA/pid" 2>/dev/null); [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; }

uid_of() { $AWK -v p="$1" '$1 == p { print $2; exit }' /data/system/packages.list; }

# ---- internet block: iptables owner-match rules in our own chain (works on Wi-Fi and mobile) ----
ipt_ready() {
  command -v iptables >/dev/null 2>&1 || return 1
  for T in iptables ip6tables; do
    command -v $T >/dev/null 2>&1 || continue
    $T -w -N lensyard_out 2>/dev/null
    $T -w -C OUTPUT -j lensyard_out 2>/dev/null || $T -w -I OUTPUT 1 -j lensyard_out 2>/dev/null
  done
  iptables -w -C OUTPUT -j lensyard_out 2>/dev/null
}
block_uid() {
  for T in iptables ip6tables; do
    command -v $T >/dev/null 2>&1 || continue
    $T -w -C lensyard_out -m owner --uid-owner "$1" -j REJECT 2>/dev/null ||
      $T -w -I lensyard_out -m owner --uid-owner "$1" -j REJECT 2>/dev/null
  done
  iptables -w -C lensyard_out -m owner --uid-owner "$1" -j REJECT 2>/dev/null
}
unblock_uid() {
  for T in iptables ip6tables; do
    command -v $T >/dev/null 2>&1 || continue
    while $T -w -C lensyard_out -m owner --uid-owner "$1" -j REJECT 2>/dev/null; do
      $T -w -D lensyard_out -m owner --uid-owner "$1" -j REJECT 2>/dev/null || break
    done
  done
}

# ---- apps that must never be disabled (could break the phone) ----
is_critical() {
  case "$1" in
    android|com.android.systemui|com.android.settings|com.android.phone|com.android.shell|com.android.providers.*|com.android.packageinstaller|com.android.permissioncontroller|com.android.inputmethod*|com.google.android.gms|com.google.android.gsf|com.google.android.packageinstaller|com.topjohnwu.magisk|me.weishu.kernelsu|com.rifsxd.ksunext|com.sukisu.ultra|me.bmax.apatch|com.termux) return 0 ;;
  esac
  H=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1 | cut -d/ -f1)
  [ -n "$H" ] && [ "$H" = "$1" ] && return 0
  I=$(settings get secure default_input_method 2>/dev/null | cut -d/ -f1)
  [ -n "$I" ] && [ "$I" = "$1" ] && return 0
  return 1
}
is_disabled() { pm list packages -d --user 0 2>/dev/null | grep -qx "package:$1"; }

do_block() {
  U=$(uid_of "$1")
  [ -n "$U" ] || { echo "fail:app not found"; return 1; }
  ipt_ready || { echo "fail:this kernel/ROM has no usable iptables"; return 1; }
  if block_uid "$U"; then list_add "$BL_FILE" "$1"; echo ok; else echo "fail:firewall rule was not accepted (kernel lacks owner match?)"; return 1; fi
}
do_unblock() {
  U=$(uid_of "$1")
  [ -n "$U" ] && unblock_uid "$U"
  list_del "$BL_FILE" "$1"; echo ok
}
do_freeze() {
  is_critical "$1" && { echo "fail:protected system app, not safe to disable"; return 1; }
  pm disable-user --user 0 "$1" >/dev/null 2>&1
  am force-stop "$1" >/dev/null 2>&1
  if is_disabled "$1"; then list_add "$FZ_FILE" "$1"; echo ok; else echo "fail:the ROM refused to disable it"; return 1; fi
}
do_unfreeze() {
  pm enable --user 0 "$1" >/dev/null 2>&1
  if is_disabled "$1"; then echo "fail:could not re-enable it"; return 1; fi
  list_del "$FZ_FILE" "$1"; echo ok
}
do_limit() {
  cmd appops set "$1" RUN_IN_BACKGROUND ignore >/dev/null 2>&1
  cmd appops set "$1" RUN_ANY_IN_BACKGROUND ignore >/dev/null 2>&1
  am set-standby-bucket "$1" restricted >/dev/null 2>&1
  am force-stop "$1" >/dev/null 2>&1
  if cmd appops get "$1" RUN_ANY_IN_BACKGROUND 2>/dev/null | grep -qi ignore; then list_add "$LM_FILE" "$1"; echo ok; else echo "fail:the ROM did not apply the limit"; return 1; fi
}
do_unlimit() {
  cmd appops set "$1" RUN_IN_BACKGROUND allow >/dev/null 2>&1
  cmd appops set "$1" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
  am set-standby-bucket "$1" active >/dev/null 2>&1
  list_del "$LM_FILE" "$1"; echo ok
}
# re-apply saved blocks after a reboot (firewall rules do not survive it)
do_reapply() {
  [ -s "$BL_FILE" ] || return 0
  ipt_ready || return 1
  while read -r p; do
    valid_pkg "$p" || continue
    U=$(uid_of "$p"); [ -n "$U" ] && block_uid "$U" >/dev/null
  done < "$BL_FILE"
}

start_rec() {
  is_running && return 0
  [ -f "$DATA/paused" ] && return 0
  NICE=""
  command -v nice >/dev/null 2>&1 && NICE="nice -n 19"
  if command -v setsid >/dev/null 2>&1; then
    setsid $NICE nohup sh "$MODDIR/recorder.sh" >/dev/null 2>&1 &
  else
    $NICE nohup sh "$MODDIR/recorder.sh" >/dev/null 2>&1 &
  fi
  sleep 1
}
stop_rec() {
  PID=$(cat "$DATA/pid" 2>/dev/null)
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null
    i=0
    while kill -0 "$PID" 2>/dev/null && [ $i -lt 6 ]; do sleep 1; i=$((i + 1)); done
  fi
  rm -f "$DATA/pid"
}
write_cfg() { printf 'INTERVAL=%s\nMAXKB=%s\nHIDE_SYSTEM=%s\n' "$INTERVAL" "$MAXKB" "$HIDE_SYSTEM" > "$DATA/config"; }
num_in() { case "$1" in ""|*[!0-9]*) return 1 ;; esac; [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]; }

# conns <TAB> pkg <TAB> servers <TAB> minutes-since-last <TAB> blocked <TAB> frozen
table() {
  M=${1:-60}
  [ -f "$LOG" ] || return 0
  NOW=$(date +%s); SINCE=$((NOW - M * 60))
  BL=" $(tr '\n' ' ' < "$BL_FILE") "; FZ=" $(tr '\n' ' ' < "$FZ_FILE") "; LM=" $(tr '\n' ' ' < "$LM_FILE") "
  $AWK -F'|' -v since="$SINCE" -v now="$NOW" -v bl="$BL" -v fz="$FZ" -v lm="$LM" '
    $1 >= since { c[$3]++; k = $3 "|" $4; if (!(k in d)) { d[k] = 1; n[$3]++ } last[$3] = $1 }
    END { for (p in c) printf "%d\t%s\t%d\t%d\t%d\t%d\t%d\n", c[p], p, n[p], int((now - last[p]) / 60), (index(bl, " " p " ") > 0), (index(fz, " " p " ") > 0), (index(lm, " " p " ") > 0) }
  ' "$LOG" | sort -rn | head -n 30
}

# epoch <TAB> ip:port   (oldest first)
timeline() {
  valid_pkg "$1" || return 1
  M=${2:-60}
  [ -f "$LOG" ] || return 0
  SINCE=$(( $(date +%s) - M * 60 ))
  $AWK -F'|' -v p="$1" -v since="$SINCE" '$3 == p && $1 >= since { print $1 "\t" $4 }' "$LOG" | tail -n 60
}

managed() {
  while read -r p; do [ -n "$p" ] && echo "B${TAB}$p"; done < "$BL_FILE"
  while read -r p; do [ -n "$p" ] && echo "F${TAB}$p"; done < "$FZ_FILE"
  while read -r p; do [ -n "$p" ] && echo "L${TAB}$p"; done < "$LM_FILE"
}

status_kv() {
  if is_running; then echo "running=1"; else echo "running=0"; fi
  if [ -f "$DATA/paused" ]; then echo "paused=1"; else echo "paused=0"; fi
  if [ -f "$LOG" ]; then echo "events=$(wc -l < "$LOG")"; else echo "events=0"; fi
  echo "interval=$INTERVAL"
  echo "maxkb=$MAXKB"
  echo "hide=$HIDE_SYSTEM"
  if [ -z "$AWK" ]; then echo "noawk=1"; else echo "noawk=0"; fi
}

status() {
  if is_running; then echo "Recorder: running"; else echo "Recorder: NOT running"; fi
  if [ -f "$LOG" ]; then echo "Events logged: $(wc -l < "$LOG")"; else echo "Events logged: 0"; fi
  echo "Scan interval: ${INTERVAL}s"
}

who() {
  M=${1:-60}
  [ -f "$LOG" ] || { echo "No data yet. Give it a few minutes."; return; }
  echo "Suspects, last $M min"
  printf "%-6s %-8s %-9s %s\n" CONNS SERVERS LAST APP
  table "$M" | while IFS="$TAB" read -r c p d l b f m; do
    printf "%-6s %-8s %-9s %s\n" "$c" "$d" "${l}m ago" "$p"
  done
}

need_pkg() { valid_pkg "$1" || { echo "fail:invalid package name"; exit 1; }; }

case "$1" in
  who|"")   who "$2" ;;
  table)    table "$2" ;;
  timeline) timeline "$2" "$3" ;;
  managed)  managed ;;
  status)   status ;;
  status-kv) status_kv ;;
  start)    start_rec; status_kv ;;
  stop)     stop_rec ;;
  restart)  stop_rec; start_rec; status_kv ;;
  clear)    : > "$LOG"; echo "cleared" ;;
  setcfg)
    case "$2" in
      INTERVAL)    num_in "$3" 2 3600 || { echo "bad value"; exit 1; }; INTERVAL=$3 ;;
      MAXKB)       num_in "$3" 100 10240 || { echo "bad value"; exit 1; }; MAXKB=$3 ;;
      HIDE_SYSTEM) { [ "$3" = 0 ] || [ "$3" = 1 ]; } || { echo "bad value"; exit 1; }; HIDE_SYSTEM=$3 ;;
      *) echo "bad key"; exit 1 ;;
    esac
    write_cfg
    if is_running; then stop_rec; start_rec; fi
    status_kv ;;
  pause)    touch "$DATA/paused"; stop_rec; status_kv ;;
  resume)   rm -f "$DATA/paused"; start_rec; status_kv ;;
  restore-all)
    while read -r p; do valid_pkg "$p" && do_unblock "$p" >/dev/null; done < "$BL_FILE"
    while read -r p; do valid_pkg "$p" && do_unfreeze "$p" >/dev/null; done < "$FZ_FILE"
    while read -r p; do valid_pkg "$p" && do_unlimit "$p" >/dev/null; done < "$LM_FILE"
    : > "$BL_FILE"; : > "$FZ_FILE"; : > "$LM_FILE"; echo ok ;;
  block)    need_pkg "$2"; do_block "$2" ;;
  unblock)  need_pkg "$2"; do_unblock "$2" ;;
  freeze)   need_pkg "$2"; do_freeze "$2" ;;
  unfreeze) need_pkg "$2"; do_unfreeze "$2" ;;
  limit)    need_pkg "$2"; do_limit "$2" ;;
  unlimit)  need_pkg "$2"; do_unlimit "$2" ;;
  reapply)  do_reapply ;;
  *) echo "Usage: who [min] | status | start | pause | resume | restart | block|unblock|freeze|unfreeze <pkg>" ;;
esac
