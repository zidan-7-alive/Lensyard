#!/system/bin/sh
# One `dumpsys power` per run, shared by the screen check and the wakelock sampler.
POWER=$DATA/power.tmp
POWER_DONE=0
power_dump() {
  [ "$POWER_DONE" = 1 ] && return 0
  dumpsys power > "$POWER" 2>/dev/null
  POWER_DONE=1
}
# true when the screen is off / dozing (false if unknown)
screen_off() {
  power_dump
  grep -m1 -o 'mWakefulness=[A-Za-z]*' "$POWER" 2>/dev/null | grep -qv Awake
}
