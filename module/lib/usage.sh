#!/system/bin/sh
# Data sent per app, counted with iptables owner-match counters (upload only: Android cannot
# attribute incoming bytes to an app with owner matching).

acct_ready() {
  command -v iptables >/dev/null 2>&1 || return 1
  for T in iptables ip6tables; do
    command -v $T >/dev/null 2>&1 || continue
    $T -w -N lensyard_acct 2>/dev/null
    $T -w -C OUTPUT -j lensyard_acct 2>/dev/null || $T -w -A OUTPUT -j lensyard_acct 2>/dev/null
  done
  iptables -w -C OUTPUT -j lensyard_acct 2>/dev/null
}
acct_sync() {
  acct_ready || return 0
  [ -f "$LOG" ] || return 0
  $AWK -F'|' -v s="$(( $(date +%s) - 86400 ))" '$1 >= s && $2 >= 10000 { print $2 }' "$LOG" | sort -u > "$DATA/acct.want"
  touch "$DATA/acct.uids"
  while read -r u; do
    [ -n "$u" ] || continue
    grep -qx "$u" "$DATA/acct.uids" && continue
    for T in iptables ip6tables; do
      command -v $T >/dev/null 2>&1 || continue
      $T -w -C lensyard_acct -m owner --uid-owner "$u" 2>/dev/null || $T -w -A lensyard_acct -m owner --uid-owner "$u" 2>/dev/null
    done
    echo "$u" >> "$DATA/acct.uids"
  done < "$DATA/acct.want"
}
acct_read() {        # "#" then uid|bytes (IPv4 + IPv6 summed)
  { echo "#"
    for T in iptables ip6tables; do
      command -v $T >/dev/null 2>&1 || continue
      $T -w -nvx -L lensyard_acct 2>/dev/null | $AWK '/owner UID match/ { print $NF "|" $2 }'
    done; } | $AWK -F'|' 'NR == 1 { print; next } { s[$1] += $2 } END { for (u in s) print u "|" s[u] }'
}
usage_update() {
  acct_ready || return 0
  d=$(date +%Y%m%d)
  [ "$(cat "$DATA/usage.date" 2>/dev/null)" = "$d" ] || { echo "#" > "$DATA/usage.today"; echo "$d" > "$DATA/usage.date"; }
  for f in usage.last usage.tot usage.today; do [ -s "$DATA/$f" ] || echo "#" > "$DATA/$f"; done
  acct_read > "$DATA/usage.cur"
  $AWK -F'|' -v outtot="$DATA/usage.tot.n" -v outtd="$DATA/usage.today.n" -v outlast="$DATA/usage.last.n" -f "$MODDIR/usage.awk" \
    "$DATA/usage.last" "$DATA/usage.tot" "$DATA/usage.today" "$DATA/usage.cur"
  mv "$DATA/usage.tot.n" "$DATA/usage.tot"; mv "$DATA/usage.today.n" "$DATA/usage.today"; mv "$DATA/usage.last.n" "$DATA/usage.last"
}
# bytes <TAB> package   (today | total)
usage_top() {
  f=usage.tot; [ "${1:-today}" = today ] && f=usage.today
  [ -f "$DATA/$f" ] || return 0
  $AWK -F'|' -v pkfile="$PKGLIST" 'BEGIN { while ((getline l < pkfile) > 0) { split(l, a, " "); if (!(a[2] in pk)) pk[a[2]] = a[1] } close(pkfile) }
    $1 != "#" && $2 > 0 { u = $1 + 0; nm = (u in pk) ? pk[u] : (((u % 100000) in pk) ? pk[u % 100000] : "uid:" u); printf "%d\t%s\n", $2, nm }' "$DATA/$f" | sort -rn | head -n 30
}

tz_offset() {
  z=$(date +%z); sg=$(printf '%s' "$z" | cut -c1); hh=$(printf '%s' "$z" | cut -c2-3); mm=$(printf '%s' "$z" | cut -c4-5)
  o=$(( ${hh#0} * 3600 + ${mm#0} * 60 )); [ "$sg" = "-" ] && o=$((0 - o)); echo "$o"
}
do_export() {
  d=$EXPORT_DIR
  mkdir -p "$d" 2>/dev/null && [ -w "$d" ] || { echo "fail:cannot write to $d"; return 1; }
  stamp=$(date +%Y%m%d-%H%M); off=$(tz_offset)
  ev="$d/lensyard-events-$stamp.csv"; us="$d/lensyard-data-sent-$stamp.csv"
  { echo "time,uid,package,address,protocol"; [ -f "$LOG" ] && $AWK -F'|' -v off="$off" -f "$MODDIR/csv.awk" "$LOG"; } > "$ev"
  { echo "package,bytes_sent_today"; usage_top today | while IFS="$TAB" read -r b p; do echo "$p,$b"; done; } > "$us"
  echo "ok:$ev"
}
