<p align="center"><img src="docs/banner.jpg" alt="Lensyard" width="100%"></p>

# Lensyard

**A flight recorder for your rooted Android phone. It logs which app opens network connections, so when something looks suspicious (a data spike, battery drain, heat) you can see exactly *who did it* and stop them with one tap.**

## Features

- **Records connections per app**: which app, which server, when. Long-lived connections are logged once, not spammed.
- **Home**: apps ranked by activity for the last 10 min / 1 h / 6 h / 24 h, with search and per-app timelines.
- **Block internet**: a firewall rule for one app (iptables owner match, IPv4 and IPv6), verified after applying and re-applied after every reboot.
- **Limit background**: stops the app and stops it running in the background; it still opens normally.
- **Freeze (disable)**: fully disables the app until you unfreeze it. Essential system apps (system UI, Settings, Phone, Google Play services, your launcher and keyboard, root managers) are protected.
- **Rules**: everything you restricted in one place, with Restore and Restore all.
- **Settings**: pause, scan interval, hide system entries, log size limit, lens refraction, auto-refresh.
- **Low power**: one long-lived scanner, lowest CPU priority, 15 s default scan, and the page only auto-refreshes while open.
- **Action button**: a quick text report from the root manager.
- **Glass bottom bar**: tap a tab or press and drag the lens across them.

Every action is checked after it runs. If your ROM refuses something, you get the real reason instead of a false "Done".

## Requirements

- A rooted phone with **KernelSU, SukiSU Ultra or KernelSU Next** (the WebUI needs their WebUI support).
  Magisk and APatch can still install it and use the **Action button**, but they have no built-in WebUI.
- Android with `iptables`/`ip6tables` and the `owner` match for **Block internet** (most Android kernels have it).
- `awk` (the module falls back to the root manager's busybox if the system has none).

## Install

1. Download `Lensyard-vX.Y.Z.zip` from the [Releases](../../releases) page (or build it yourself, see below).
2. In your root manager open **Module → Install**, pick the zip, then reboot.
3. Wait about a minute, then open the module's **WebUI**.

## Using it

1. Open **Home** and look at the top of the list for apps you did not expect.
2. Tap an app to see its timeline and the three actions.
3. Use **Rules** to undo anything.

Optional terminal command (not required): `su`, then `lensyard who`, `lensyard status`, `lensyard block <package>` and so on.

## How it works

```
module/
  module.prop        metadata
  customize.sh       install-time defaults
  service.sh         after boot: re-apply blocks, start the recorder
  recorder.sh        sends a tick every N seconds through a FIFO
  scan.awk           one long-lived awk: reads /proc/net/tcp(6), maps uid -> package, logs new connections
  lensyard.sh        control script used by the WebUI, Action button and terminal
  action.sh          Action button report
  webroot/           the WebUI (static page, talks to lensyard.sh through the manager's bridge)
```

- Connections come from `/proc/net/tcp` and `/proc/net/tcp6` (state ESTABLISHED / SYN_SENT). The owning uid is mapped to a package through `/data/system/packages.list`.
- Log lines: `epoch|uid|package|ip:port|tcp` in `/data/adb/lensyard/events.log`, trimmed to your size limit.
- The recorder avoids restarting processes every cycle, which keeps the phone cool. mawk's input buffering is handled automatically.
- Everything the WebUI sends to the shell is validated (package names, numbers, a whitelist of settings).

## Limits (honest ones)

- It sees connections that are still open when a scan runs, so very short ones can be missed. Raise the scan rate in Settings to catch more (at a small battery cost).
- TCP only for now. Wakeups, wakelocks and file access are ideas for later versions.
- Blocking relies on kernel firewall support. If the kernel lacks the owner match, the module says so.
- Tested mainly in a simulated environment and on one device (Redmi Note 13 4G, Evolution X, SukiSU). Reports from other devices are welcome.

## Uninstall

Remove the module in your root manager and reboot. Restore your restrictions first (Rules → Restore all) so nothing stays blocked or disabled. Data lives in `/data/adb/lensyard/` and is removed with the module.

## Contributing

Issues and pull requests are welcome. Keep scripts POSIX `sh` (Android's mksh/toybox), validate every value that reaches a shell command, and make every change undoable.

