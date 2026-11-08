# Adds the growth of each app's sent-bytes counter to the running totals.
# Inputs (each starts with a "#" line): last, total, today, current. Fields split by "|".
FNR == 1 { f++ }
f == 1 { last[$1] = $2; next }
f == 2 { tot[$1] = $2; next }
f == 3 { td[$1] = $2; next }
f == 4 {
  c = $2 + 0
  d = (($1 in last) && c >= last[$1]) ? c - last[$1] : c
  tot[$1] += d; td[$1] += d; nl[$1] = c
}
END {
  print "#" > outtot;  for (u in tot) if (u != "#") print u "|" tot[u] > outtot
  print "#" > outtd;   for (u in td)  if (u != "#") print u "|" td[u] > outtd
  print "#" > outlast; for (u in nl) print u "|" nl[u] > outlast
}
