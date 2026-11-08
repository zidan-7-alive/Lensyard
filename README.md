<p align="center"><img src="docs/banner.jpg" alt="Lensyard - see beyond the frame" width="100%"></p>

# Lensyard

**See beyond the frame. A flight recorder for your rooted Android phone: which app uses the network, which one keeps it awake, which one heats it up, and one tap (or one rule) to stop it.**

Pure shell, no extra binaries. Everything runs from the module's own WebUI, so you never need a terminal. By [zidan-7-alive](https://github.com/zidan-7-alive).

## What it does

| Tab | What you get |
|---|---|
| **Home** | Apps ranked by network activity (10 min / 1 h / 6 h / 24 h), search, per-app timelines. Tap an app to **Block internet**, **Limit background** or **Freeze (disable)**. |
| **Battery** | Level, temperature, charging state and current; a temperature chart; apps holding wakelocks. A **heat guard** warns when the battery stays hot, names the busiest app and can limit it automatically. |
| **Rules** | **Smart rules**: block or limit an app only at certain hours, only while the screen is off, only on Wi-Fi or only on mobile data, or only if it opens too many connections per hour. Plus everything you restricted, with Restore / Restore all. |
| **Alerts** | Heat warnings, first-time network apps and a daily report (optional system notifications). **Data sent per app** (today / total) and **CSV export** to your Download folder. |
| **Settings** | Pause, scan interval, battery sampling, heat limit, notifications, daily report time, log size, theme (**AMOLED black** or Classic dark), lens refraction, and a **Diagnostics** button that checks what your phone really supports. |

Every action is checked after it runs. If your ROM refuses something you get the real reason, not a fake "Done".

The bottom bar is a glass pill: tap a tab, or press and drag the lens across them.

## Requirements

- A rooted phone with **KernelSU, SukiSU Ultra or KernelSU Next** (the WebUI needs their WebUI support). Magisk and APatch can install it and use the **Action button**, which prints a quick report.
- `iptables` / `ip6tables` with the `owner` match for Block, Smart rules and Data sent (most Android kernels have it). Run **Diagnostics** to see.
- `awk` (the module falls back to the root manager's busybox).

## Install and updates

1. Download `Lensyard-vX.Y.Z.zip` from [Releases](../../releases), open **Module → Install** in your root manager, pick the zip, reboot.
2. After that, **updates are automatic**: the module points your root manager at this repo (`update.json`), so new versions show up as an update on the module card. Your settings are kept.

## How it works

```
module/
  module.prop     metadata + updateJson (OTA)
  service.sh      after boot: rebuild firewall rules, start the worker
  recorder.sh     sends a tick every N seconds through a FIFO
  scan.awk        one long-lived awk: /proc/net/tcp(6) -> app -> log
  lensyard.sh     control script used by the WebUI, Action button and terminal
  lib/            battery + heat, smart rules, alerts + daily report, data sent, diagnostics
  webroot/        the WebUI (static page; talks to lensyard.sh through the manager's bridge)
```

- Connections come from `/proc/net/tcp` and `/proc/net/tcp6`; the owning uid is mapped to a package via `packages.list`. Log lines look like `epoch|uid|package|ip:port|tcp`.
- Once a minute the worker also samples battery temperature and wakelocks (`dumpsys power`), evaluates smart rules, looks for first-time apps, updates data-sent counters and checks the daily report time.
- **Block / smart rules** use iptables owner-match rules in their own chains (`lensyard_out`, `lensyard_rules`); **Data sent** uses counters in `lensyard_acct`. All are rebuilt after every reboot and removed on uninstall.
- Low power by design: one long-lived scanner, lowest CPU priority, one `dumpsys` per minute at most, and the WebUI refreshes only while open.
- Everything the WebUI sends to the shell is validated (package names, numbers, a whitelist of settings).

## Limits (honest ones)

- Connections are seen when a scan runs, so very short ones can be missed. A faster scan catches more at a small battery cost.
- TCP only. **Data sent counts uploads only**: Android cannot attribute incoming bytes to an app with owner matching.
- Battery readings and notifications depend on your ROM. **Diagnostics** shows what works. Notification display is not verifiable from the module.
- Blocking needs kernel firewall support; the module says so if it is missing.
- Tested mainly in a simulated environment and on one device (Redmi Note 13 4G, Evolution X, SukiSU). Reports from other devices are welcome.

## Uninstall

Remove the module in your root manager and reboot. Uninstalling restores frozen, limited and blocked apps, removes the firewall chains it added and deletes `/data/adb/lensyard/`.

## For the maintainer: publishing a release (Termux)

One-time: `pkg install git python gh` then `gh auth login`.

```
sh release.sh v2.3.0 "What changed"
```

This bumps the version, adds a changelog line, builds the zip, pushes the code, creates the GitHub Release with the zip attached, and then updates `update.json` so every phone sees the update. `sh release.sh` with no arguments re-releases the current version.

Build only: `python tools/package.py module --out dist`.

## Contributing

Issues and pull requests are welcome. Keep scripts POSIX `sh` (Android's mksh/toybox), validate every value that reaches a shell command, and make every change undoable.

## License

MIT, see [LICENSE](LICENSE).
