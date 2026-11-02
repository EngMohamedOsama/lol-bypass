# LoL Bypass

Play **League of Legends, TFT, Legends of Runeterra and VALORANT without a VPN** on Egyptian ISPs that block Riot through DPI.
A small Windows tray app with a Riot-style window. It starts hidden with Windows, uses no VPN, and adds no extra ping.

> العب ليج أوف ليجندز و TFT و Runeterra و فالورانت من غير VPN على النت المصري. البرنامج بيشتغل لوحده مع الويندوز في الـ tray.

## What it fixes

| Problem (with no VPN) | Cause | Fix |
|---|---|---|
| Can't log in | ISP intercepts TLS to `auth.riotgames.com` (fake certificate) | GoodbyeDPI splits the TLS hello so the DPI can't read the server name |
| Chat offline | Port 5223 reset | GoodbyeDPI also covers ports 5222/5223 |
| `VAN 84` / "Vanguard session is initializing" | Vanguard (`vgc`) connection on port 8443 is cut | GoodbyeDPI covers 8443, and `vgc` is restarted behind the bypass |
| Match won't load: "Failed to Connect" / reconnect loop | DPI drops the first UDP packets to the match server | zapret `winws` sends fake packets ahead of the real ones on match-server UDP |

## Supported

- **League of Legends:** Normal, Ranked, ARAM, Arena, Swarm, Practice Tool, Custom (all modes use the same servers)
- **Teamfight Tactics**
- **Legends of Runeterra** (HTTPS only)
- **VALORANT:** UDP 7000-8999 to any server, since some of its servers are outside Riot's own IP ranges

Tested end to end on League (EUNE). The other games use the same login, chat and Vanguard path. If a match won't connect, try another match strategy.

## Install

1. Download the repo (**Code → Download ZIP**) and extract it, or `git clone` it.
2. Run **`Install.bat`** and accept the admin prompt.
3. Answer **Y** to the Windows Defender exclusion (recommended, see below).

It installs to `C:\LoL-Bypass`, opens the window, and from then on starts **hidden in the tray** at every Windows logon with no admin prompt.

## Use

- **LoL Bypass** shortcut (Desktop / Start menu): opens the window.
- **START / STOP BYPASS**: the big button.
- **Match strategy 1-4**: if matches fail to connect on a PC, try the next one. Your choice is saved in `config.ini`.
- **Start with Windows**: turns auto-start on or off.
- Tray icon: **click** to open the window; **right-click** for Restart, Stop, Log or Exit.
- Closing the window keeps the bypass running in the tray.
- Log: `C:\LoL-Bypass\bypass.log`

## Antivirus

GoodbyeDPI and zapret use the **WinDivert** packet driver, which antivirus programs often flag as a false positive. If `winws.exe` or `goodbyedpi.exe` disappears, add an exclusion for `C:\LoL-Bypass` (and the folder you installed from), then run `Install.bat` again.

## How it works

```
Riot Client / League / VALORANT
 ├─ TCP 443, 8443, 2099, 5222/5223, 8088, 8393-8400  →  GoodbyeDPI -1   (login, chat, Vanguard, store)
 └─ UDP 5000-9999 → Riot IP ranges (riot-game-ips.txt) →  zapret winws    (LoL / TFT match servers)
    UDP 7000-8999 → any IP                              →  zapret winws    (VALORANT match servers)
```

## Uninstall

`C:\LoL-Bypass\Uninstall.bat` removes the tasks, shortcuts, Defender exclusion and the folder.

## Credits & licenses

- [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI) by ValdikSS, Apache-2.0
- [zapret](https://github.com/bol-van/zapret) by bol-van, MIT
- [WinDivert](https://github.com/basil00/WinDivert) by basil00, LGPL-3.0 / GPL-2.0

Bundled binaries are unmodified upstream builds (GoodbyeDPI 0.2.3rc3, zapret-win-bundle). License texts are in `licenses/`.
