# Changelog

## v2.2.0
Three big updates in one release, plus over-the-air updates and a new look.

**Battery and heat**
- New Battery tab: level, temperature, charging state and current, a temperature chart (6 h / 24 h) and the apps holding wakelocks.
- Heat guard: alerts when the battery stays hot, names the busiest app, and can limit it automatically (off by default; never touches essential system apps).
- Diagnostics button checks what your phone and ROM actually support.

**Smart rules**
- Per-app rules: block or limit an app only during certain hours, only while the screen is off, only on Wi-Fi or only on mobile data, or only if it opens too many connections per hour.
- Rules are re-applied after every reboot and are easy to delete.

**Alerts and reports**
- New Alerts tab: heat warnings, first-time network apps and a daily report (optional system notifications).
- Data sent per app (today / total). Incoming data cannot be attributed per app this way.
- Export the connection log and data-sent table as CSV files.

**Updates and look**
- OTA: your root manager now checks GitHub and updates the module for you. Settings are kept on update.
- New banner and an AMOLED black theme (default); the old look is still available as "Classic dark".
- Uninstalling now restores frozen, limited and blocked apps and removes every firewall rule it added.
- `release.sh` publishes a release and the OTA update from Termux in one command.

## v1.3.3
- Bottom bar redesigned to match the root manager's own: compact, nearly clear glass pill with a thin rim.
- Selected tab is a soft highlight; pressing and dragging swells it into a glass lens that magnifies and refracts.

## v1.3.2
- Fixed the bottom bar background collapsing to a thin line (CSS class name clash).
- Glassier bar and lens.

## v1.3.1
- Magnifying lens with SVG refraction; "Lens refraction" switch in Settings.

## v1.3.0
- Block internet now uses firewall (iptables owner-match) rules in its own chain, verified after applying and re-applied on every boot.
- Freeze now really disables the app (`pm disable-user`); essential system apps are protected.
- New "Limit background" action (appops + restricted standby bucket).
- Every action is verified; failures show the real reason instead of a false "Done".
- Draggable bottom dock.

## v1.2.0
- Low-power recorder: one long-lived awk process fed by ticks over a FIFO, lowest CPU priority, 15 s default interval.
- WebUI redesign: Home / Rules / Settings, app search, activity bars, settings (pause, interval, hide system entries, log size, auto-refresh).

## v1.1.0
- WebUI and Action button, so nothing needs the terminal.

## v1.0.1
- Banner image.

## v1.0.0
- First version: shell recorder of per-app network connections with a small command-line report.
