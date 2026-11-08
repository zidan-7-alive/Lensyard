#!/system/bin/sh
# Battery temperature / level samples, wakelock samples and the heat guard.

batt_read() {
  L=$(cat "$SYS/capacity" 2>/dev/null); T=$(cat "$SYS/temp" 2>/dev/null)
  S=$(cat "$SYS/status" 2>/dev/null); C=$(cat "$SYS/current_now" 2>/dev/null)
  case "$T" in ""|*[!0-9-]*) T="" ;; esac
  # temp is normally tenths of a degree C (312 = 31.2). If it looks like whole degrees, convert.
  [ -n "$T" ] && [ "$T" -gt 0 ] && [ "$T" -lt 100 ] && T=$((T * 10))
}
batt_sample() {      # epoch
  batt_read
  [ -n "$T" ] || return 1
  echo "$1|${L:-0}|$T|${S:-Unknown}|${C:-0}" >> "$DATA/battery.log"
}
wake_sample() {      # epoch
  power_dump
  [ -s "$POWER" ] || return 0
  $AWK -v ts="$1" -v lf="$DATA/wake.log" -v pkfile="$PKGLIST" -f "$MODDIR/wake.awk" "$POWER"
}
batt_kv() {
  batt_read
  echo "level=${L:-?}"; echo "temp=${T:-?}"; echo "bstatus=${S:-?}"; echo "current=${C:-0}"
}
# epoch <TAB> level <TAB> temp(tenths) <TAB> status, at most ~120 points
batt_series() {
  H=${1:-6}
  [ -f "$DATA/battery.log" ] || return 0
  SINCE=$(( $(date +%s) - H * 3600 ))
  $AWK -F'|' -v since="$SINCE" '$1 >= since { n++; a[n] = $1 "\t" $2 "\t" $3 "\t" $4 }
    END { step = int(n / 120) + 1; for (i = 1; i <= n; i += step) print a[i] }' "$DATA/battery.log"
}
# samples-held <TAB> package <TAB> most common tag
wake_top() {
  M=${1:-60}
  [ -f "$DATA/wake.log" ] || return 0
  SINCE=$(( $(date +%s) - M * 60 ))
  $AWK -F'|' -v since="$SINCE" '$1 >= since && $3 !~ /^uid:/ {
      c[$3]++; k = $3 SUBSEP $4; t[k]++; if (t[k] > best[$3]) { best[$3] = t[k]; tag[$3] = $4 } }
    END { for (p in c) printf "%d\t%s\t%s\n", c[p], p, tag[p] }' "$DATA/wake.log" | sort -rn | head -n 15
}

# Called after every battery sample. Two hot samples in a row => one alert per 30 minutes.
heat_check() {       # epoch
  batt_read
  [ -n "$T" ] || return 0
  if [ "$T" -ge $((HEAT_C * 10)) ]; then
    c=$(cat "$DATA/heat.count" 2>/dev/null); c=$(( ${c:-0} + 1 )); echo "$c" > "$DATA/heat.count"
  else
    echo 0 > "$DATA/heat.count"; return 0
  fi
  [ "$c" -ge 2 ] || return 0
  last=$(cat "$DATA/heat.last" 2>/dev/null); [ $(( $1 - ${last:-0} )) -ge 1800 ] || return 0
  echo "$1" > "$DATA/heat.last"
  SINCE=$(( $1 - 600 ))
  busy=$([ -f "$LOG" ] && $AWK -F'|' -v s="$SINCE" '$1 >= s && $3 !~ /^uid:/ { c[$3]++ }
    END { m = 0; for (p in c) if (c[p] > m) { m = c[p]; b = p } if (b != "") print b " " m }' "$LOG")
  wk=$([ -f "$DATA/wake.log" ] && $AWK -F'|' -v s="$SINCE" '$1 >= s && $3 !~ /^uid:/ { c[$3]++ }
    END { m = 0; for (p in c) if (c[p] > m) { m = c[p]; b = p } if (b != "") print b }' "$DATA/wake.log")
  msg="Phone is $((T / 10)).$((T % 10))C."
  [ -n "$busy" ] && msg="$msg Busiest app: ${busy% *} (${busy#* } connections)."
  [ -n "$wk" ] && msg="$msg Holding wakelocks: $wk."
  pkg="${busy% *}"
  if [ "$AUTO_HEAT" = 1 ] && valid_pkg "$pkg" && ! is_critical "$pkg"; then
    if do_limit "$pkg" >/dev/null; then msg="$msg Limited $pkg automatically."; fi
  fi
  alert_add heat "$pkg" "$msg"
}
