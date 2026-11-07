# Streaming scanner. Each input line is one "tick" (epoch seconds).
# On every tick it reads /proc/net/tcp(6) and logs connections that were not open at the previous tick.
function hex(s,   i, n, d) {
  n = 0; s = toupper(s)
  for (i = 1; i <= length(s); i++) {
    d = index("0123456789ABCDEF", substr(s, i, 1)) - 1
    n = n * 16 + d
  }
  return n
}
function v4(h) {
  return hex(substr(h,7,2)) "." hex(substr(h,5,2)) "." hex(substr(h,3,2)) "." hex(substr(h,1,2))
}
function v6(h,   i, g, o) {
  o = ""
  for (i = 0; i < 4; i++) {
    g = tolower(substr(h, i*8+1, 8))
    o = o (i ? ":" : "") substr(g,7,2) substr(g,5,2) ":" substr(g,3,2) substr(g,1,2)
  }
  return o
}
function load_pk(   line) {
  delete pk
  while ((getline line < pkfile) > 0) {
    split(line, pa, " ")
    if (!(pa[2] in pk)) pk[pa[2]] = pa[1]
  }
  close(pkfile)
}
function scan(file,   line, n, h, port, ip, uid, addr, key, name) {
  while ((getline line < file) > 0) {
    n = split(line, fl, " ")
    if (n < 8) continue
    if (fl[4] != "01" && fl[4] != "02") continue
    split(fl[3], ad, ":"); h = ad[1]; port = hex(ad[2])
    if (length(h) == 8) ip = v4(h)
    else if (toupper(substr(h,1,24)) == "0000000000000000FFFF0000") ip = v4(substr(h,25,8))
    else if (h ~ /^0+$/ || toupper(h) == "00000000000000000000000001000000") continue
    else ip = v6(h)
    if (ip ~ /^127\./ || ip == "0.0.0.0") continue
    uid = fl[8] + 0
    if (hide == 1 && uid < 10000) continue
    addr = (ip ~ /:/) ? "[" ip "]:" port : ip ":" port
    key = uid "|" addr
    if (key in cur) continue
    cur[key] = 1
    if (!(key in prev)) {
      if (uid in pk) name = pk[uid]
      else if (((uid % 100000) in pk)) name = pk[uid % 100000]
      else name = "uid:" uid
      out = out ts "|" uid "|" name "|" addr "|tcp\n"
    }
  }
  close(file)
}
BEGIN { load_pk() }
{
  ts = $1
  tick++
  if (tick % 40 == 0) load_pk()
  delete cur
  out = ""
  scan("/proc/net/tcp")
  scan("/proc/net/tcp6")
  if (out != "") { printf "%s", out >> lf; close(lf) }
  delete prev
  for (k in cur) prev[k] = 1
}
