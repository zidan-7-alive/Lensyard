# Parses `dumpsys power`: logs every (uid, tag) holding a PARTIAL_WAKE_LOCK at this moment.
BEGIN {
  while ((getline l < pkfile) > 0) { split(l, a, " "); if (!(a[2] in pk)) pk[a[2]] = a[1] }
  close(pkfile)
}
/PARTIAL_WAKE_LOCK/ {
  if (!match($0, /uid=[0-9]+/)) next
  u = substr($0, RSTART + 4, RLENGTH - 4) + 0
  tag = ""
  if (match($0, /'[^']*'/)) tag = substr($0, RSTART + 1, RLENGTH - 2)
  gsub(/\|/, "/", tag)
  key = u "|" tag
  if (key in seen) next
  seen[key] = 1
  if (u in pk) nm = pk[u]
  else if (((u % 100000) in pk)) nm = pk[u % 100000]
  else nm = "uid:" u
  print ts "|" u "|" nm "|" tag >> lf
}
END { close(lf) }
