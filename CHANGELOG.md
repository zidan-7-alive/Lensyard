# Changelog

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
