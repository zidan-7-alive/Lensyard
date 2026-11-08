#!/system/bin/sh
# Diagnostics: what this phone / ROM actually supports. One line each: name|ok/warn/fail|detail
dline() { printf '%s|%s|%s\n' "$1" "$2" "$3"; }
run_diag() {
  dline "Device" ok "$(getprop ro.product.model) / Android $(getprop ro.build.version.release) / kernel $(uname -r)"
  if [ -n "$AWK" ]; then dline "awk" ok "$AWK"; else dline "awk" fail "not found, recording cannot work"; fi
  [ -r "$PKGLIST" ] && dline "App list" ok "packages.list readable" || dline "App list" fail "cannot read $PKGLIST"
  [ -r /proc/net/tcp ] && dline "Connection table" ok "/proc/net/tcp readable" || dline "Connection table" fail "/proc/net/tcp not readable"
  if command -v iptables >/dev/null 2>&1; then
    iptables -w -N lensyard_diag 2>/dev/null
    if iptables -w -A lensyard_diag -m owner --uid-owner 99999 -j REJECT 2>/dev/null; then
      dline "Firewall (block)" ok "iptables owner match works"
      iptables -w -F lensyard_diag 2>/dev/null
    else dline "Firewall (block)" fail "kernel rejected the owner match; Block will not work"; fi
    iptables -w -X lensyard_diag 2>/dev/null
  else dline "Firewall (block)" fail "iptables not found"; fi
  command -v ip6tables >/dev/null 2>&1 && dline "Firewall IPv6" ok "ip6tables found" || dline "Firewall IPv6" warn "no ip6tables; IPv6 traffic is not blocked or counted"
  if [ -r "$SYS/temp" ]; then dline "Battery sensor" ok "temp $(cat "$SYS/temp") (tenths of C), level $(cat "$SYS/capacity" 2>/dev/null)%"; else dline "Battery sensor" fail "cannot read $SYS/temp"; fi
  [ -r "$SYS/current_now" ] && dline "Battery current" ok "readable" || dline "Battery current" warn "not readable (optional)"
  power_dump
  if [ -s "$POWER" ]; then
    n=$(grep -c PARTIAL_WAKE_LOCK "$POWER")
    dline "Wakelocks" ok "dumpsys power works, $n held right now"
    if grep -q 'mWakefulness=' "$POWER"; then dline "Screen state" ok "detected"; else dline "Screen state" warn "not detected; screen-off rules will never trigger"; fi
  else dline "Wakelocks" fail "dumpsys power gave no output"; fi
  command -v pm >/dev/null 2>&1 && dline "Freeze (disable)" ok "pm available" || dline "Freeze (disable)" fail "pm not found"
  if cmd appops help >/dev/null 2>&1; then dline "Background limit" ok "appops available"; else dline "Background limit" fail "cmd appops unavailable"; fi
  if cmd notification help >/dev/null 2>&1; then dline "Notifications" ok "cmd notification available (display not verified)"; else dline "Notifications" warn "not available; alerts stay inside the app"; fi
  mkdir -p "$EXPORT_DIR" 2>/dev/null && [ -w "$EXPORT_DIR" ] && dline "Export folder" ok "$EXPORT_DIR" || dline "Export folder" warn "cannot write to $EXPORT_DIR"
}
