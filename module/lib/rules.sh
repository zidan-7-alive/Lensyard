#!/system/bin/sh
# Smart rules. One line per rule in rules.conf:  id|package|net|window|screen|conns|action
#   net     any | wifi | mobile          (block only that kind of traffic)
#   window  - | HH:MM-HH:MM              (daily time window, may cross midnight)
#   screen  - | off                      (only while the screen is off)
#   conns   - | N                        (only if the app opened more than N connections in the last hour)
#   action  block | limit
RULES=$DATA/rules.conf

rule_ok_window() { [ "$1" = "-" ] || printf '%s' "$1" | grep -qE '^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$'; }
hm_val() { hh=${1%:*}; mm=${1#*:}; echo $(( ${hh#0} * 100 + ${mm#0} )); }
now_val() { hh=$(date +%H); mm=$(date +%M); echo $(( ${hh#0} * 100 + ${mm#0} )); }
count_recent() {     # package minutes
  $AWK -F'|' -v p="$1" -v s="$(( $(date +%s) - $2 * 60 ))" '$3 == p && $1 >= s { n++ } END { print n + 0 }' "$LOG" 2>/dev/null
}

# 0 = the rule's conditions are all true right now
rule_cond() {        # package window screen conns
  if [ "$2" != "-" ]; then
    s=$(hm_val "${2%-*}"); e=$(hm_val "${2#*-}"); n=$(now_val)
    if [ "$s" -le "$e" ]; then [ "$n" -ge "$s" ] && [ "$n" -lt "$e" ] || return 1
    else [ "$n" -ge "$s" ] || [ "$n" -lt "$e" ] || return 1; fi
  fi
  if [ "$3" = "off" ]; then screen_off || return 1; fi
  if [ "$4" != "-" ]; then [ "$(count_recent "$1" 60)" -gt "$4" ] || return 1; fi
  return 0
}

rules_chain_ready() {
  command -v iptables >/dev/null 2>&1 || return 1
  for T in iptables ip6tables; do
    command -v $T >/dev/null 2>&1 || continue
    $T -w -N lensyard_rules 2>/dev/null
    $T -w -C OUTPUT -j lensyard_rules 2>/dev/null || $T -w -I OUTPUT 1 -j lensyard_rules 2>/dev/null
  done
  iptables -w -C OUTPUT -j lensyard_rules 2>/dev/null
}
rules_apply_chain() {
  rules_chain_ready || return 1
  for T in iptables ip6tables; do
    command -v $T >/dev/null 2>&1 || continue
    $T -w -F lensyard_rules 2>/dev/null
    while IFS='|' read -r u net; do
      [ -n "$u" ] || continue
      case "$net" in wifi) o="-o wlan+" ;; mobile) o="! -o wlan+" ;; *) o="" ;; esac
      $T -w -A lensyard_rules -m owner --uid-owner "$u" $o -j REJECT 2>/dev/null
    done < "$DATA/rules.des"
  done
}

rules_eval() {
  touch "$RULES" "$DATA/rules.applied" "$DATA/rules.lim"
  : > "$DATA/rules.des"; : > "$DATA/rules.deslim"; : > "$DATA/rules.active"
  while IFS='|' read -r id pkg net win scr conns action; do
    [ -n "$id" ] || continue
    rule_cond "$pkg" "$win" "$scr" "$conns" || continue
    echo "$id" >> "$DATA/rules.active"
    case "$action" in
      block) U=$(uid_of "$pkg"); [ -n "$U" ] && echo "$U|$net" >> "$DATA/rules.des" ;;
      limit) echo "$pkg" >> "$DATA/rules.deslim" ;;
    esac
  done < "$RULES"
  sort -u "$DATA/rules.des" > "$DATA/rules.des.s"; mv "$DATA/rules.des.s" "$DATA/rules.des"
  sort -u "$DATA/rules.deslim" > "$DATA/rules.deslim.s"; mv "$DATA/rules.deslim.s" "$DATA/rules.deslim"
  if ! cmp -s "$DATA/rules.des" "$DATA/rules.applied"; then
    if rules_apply_chain || [ ! -s "$DATA/rules.des" ]; then cp "$DATA/rules.des" "$DATA/rules.applied"; fi
  fi
  while read -r p; do
    [ -n "$p" ] || continue
    grep -qx "$p" "$DATA/rules.lim" || do_limit "$p" >/dev/null
  done < "$DATA/rules.deslim"
  while read -r p; do
    [ -n "$p" ] || continue
    grep -qx "$p" "$DATA/rules.deslim" || do_unlimit "$p" >/dev/null
  done < "$DATA/rules.lim"
  cp "$DATA/rules.deslim" "$DATA/rules.lim"
}

rule_add() {         # package net window screen conns action
  valid_pkg "$1" || { echo "fail:invalid package"; return 1; }
  case "$2" in any|wifi|mobile) ;; *) echo "fail:bad network option"; return 1 ;; esac
  rule_ok_window "$3" || { echo "fail:bad time window"; return 1; }
  case "$4" in -|off) ;; *) echo "fail:bad screen option"; return 1 ;; esac
  if [ "$5" != "-" ]; then num_in "$5" 1 9999 || { echo "fail:bad connection limit"; return 1; }; fi
  case "$6" in block|limit) ;; *) echo "fail:bad action"; return 1 ;; esac
  touch "$RULES"
  [ "$(wc -l < "$RULES")" -lt 30 ] || { echo "fail:too many rules (30 max)"; return 1; }
  id="r$(date +%s)$(wc -l < "$RULES" | tr -d ' ')"
  while grep -q "^$id|" "$RULES"; do id="${id}x"; done
  echo "$id|$1|$2|$3|$4|$5|$6" >> "$RULES"
  rules_eval
  echo ok
}
rule_del() {
  case "$1" in r[0-9]*) ;; *) echo "fail:bad rule id"; return 1 ;; esac
  case "$1" in *[!A-Za-z0-9]*) echo "fail:bad rule id"; return 1 ;; esac
  grep -v "^$1|" "$RULES" > "$RULES.tmp"; mv "$RULES.tmp" "$RULES"
  rules_eval
  echo ok
}
rules_list() {       # id pkg net window screen conns action active
  touch "$RULES"
  while IFS='|' read -r id pkg net win scr conns action; do
    [ -n "$id" ] || continue
    a=0; grep -qx "$id" "$DATA/rules.active" 2>/dev/null && a=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$pkg" "$net" "$win" "$scr" "$conns" "$action" "$a"
  done < "$RULES"
}
