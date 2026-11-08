#!/system/bin/sh
# Alerts: log + optional system notification, new-app detector, daily report.

notify() {           # message  (at most one notification every 2 minutes)
  [ "$NOTIFY" = 1 ] || return 0
  now=$(date +%s); last=$(cat "$DATA/notify.last" 2>/dev/null)
  [ $(( now - ${last:-0} )) -ge 120 ] || return 0
  echo "$now" > "$DATA/notify.last"
  cmd notification post -t Lensyard "ly$now" "$1" >/dev/null 2>&1
}
alert_add() {        # type pkg message
  ts=$(date +%s)
  msg=$(printf '%s' "$3" | tr -d '|\n\r' | cut -c1-300)
  echo "$ts|$1|$2|$msg" >> "$DATA/alerts.log"
  trim_file alerts.log 300
  notify "$msg"
}
# ts <TAB> type <TAB> package <TAB> message, newest first
alerts_list() {
  [ -f "$DATA/alerts.log" ] || return 0
  tail -n "${1:-60}" "$DATA/alerts.log" | sed '1!G;h;$!d' | while IFS='|' read -r ts type pkg msg; do
    printf '%s\t%s\t%s\t%s\n' "$ts" "$type" "$pkg" "$msg"
  done
}
alerts_unread() {
  r=$(cat "$DATA/alerts.read" 2>/dev/null)
  [ -f "$DATA/alerts.log" ] || { echo 0; return; }
  $AWK -F'|' -v r="${r:-0}" '$1 > r { n++ } END { print n + 0 }' "$DATA/alerts.log"
}

# First network activity from a package we have never seen. The first run only learns silently.
newapp_check() {
  [ -f "$LOG" ] || return 0
  if [ ! -f "$DATA/seen.pkgs" ]; then
    { echo "#"; $AWK -F'|' '$3 !~ /^uid:/ { print $3 }' "$LOG" | sort -u; } > "$DATA/seen.pkgs"
    return 0
  fi
  $AWK -F'|' 'NR == FNR { s[$1] = 1; next } $3 !~ /^uid:/ && !($3 in s) { n[$3] = 1 } END { for (p in n) print p }' \
    "$DATA/seen.pkgs" "$LOG" > "$DATA/new.tmp"
  [ -s "$DATA/new.tmp" ] || return 0
  cat "$DATA/new.tmp" >> "$DATA/seen.pkgs"
  [ "$NEWAPP" = 1 ] || return 0
  cnt=$(wc -l < "$DATA/new.tmp")
  if [ "$cnt" -le 3 ]; then
    while read -r p; do alert_add newapp "$p" "New app on the network: $p"; done < "$DATA/new.tmp"
  else
    alert_add newapp "" "$cnt apps used the network for the first time"
  fi
}

daily_report() {
  now=$(date +%s); since=$((now - 86400))
  [ -f "$LOG" ] || { alert_add daily "" "Daily report: no network activity recorded yet."; return; }
  top=$($AWK -F'|' -v s="$since" '$1 >= s && $3 !~ /^uid:/ { c[$3]++ } END { for (p in c) print c[p], p }' "$LOG" \
    | sort -rn | head -n 5 | $AWK '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $2, $1 }')
  total=$($AWK -F'|' -v s="$since" '$1 >= s { n++ } END { print n + 0 }' "$LOG")
  apps=$($AWK -F'|' -v s="$since" '$1 >= s && $3 !~ /^uid:/ { a[$3] = 1 } END { for (p in a) n++; print n + 0 }' "$LOG")
  msg="Daily report: $total connections from $apps apps."
  [ -n "$top" ] && msg="$msg Top: $top."
  if [ -f "$DATA/battery.log" ]; then
    pk=$($AWK -F'|' -v s="$since" '$1 >= s && $3 > m { m = $3 } END { if (m > 0) printf "%d.%d", int(m / 10), m % 10 }' "$DATA/battery.log")
    [ -n "$pk" ] && msg="$msg Peak battery temp ${pk}C."
  fi
  alert_add daily "" "$msg"
}
daily_check() {
  case "$DAILY_AT" in ""|*[!0-9]*) return 0 ;; esac
  [ "$DAILY_AT" -le 23 ] || return 0
  today=$(date +%Y%m%d); h=$(date +%H)
  [ "${h#0}" = "" ] && h=0 || h=${h#0}
  [ "$h" -ge "$DAILY_AT" ] || return 0
  [ "$(cat "$DATA/daily.last" 2>/dev/null)" = "$today" ] && return 0
  echo "$today" > "$DATA/daily.last"
  daily_report
}
