# Event log -> CSV with readable local times. Pass -v off=<seconds east of UTC>.
function iso(t,   s, z, era, doe, yoe, y, doy, mp, d, m, h, mi, se) {
  t += off; s = t % 86400
  z = int(t / 86400) + 719468
  era = int(z / 146097); doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400
  doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
  mp = int((5 * doy + 2) / 153)
  d = doy - int((153 * mp + 2) / 5) + 1
  m = mp + (mp < 10 ? 3 : -9)
  if (m <= 2) y++
  h = int(s / 3600); mi = int((s % 3600) / 60); se = s % 60
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d", y, m, d, h, mi, se)
}
{ print iso($1) "," $2 "," $3 "," $4 "," $5 }
