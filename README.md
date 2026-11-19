# dotfiles

A Hyprland desktop built with [Quickshell](https://quickshell.org): a floating bar, desktop
widgets, dropdown popups, a notification daemon, an Alt+Tab switcher, a wallpaper switcher, an
AI side panel and an Evangelion-style lock screen. Colours follow your wallpaper through
[matugen](https://github.com/InioX/matugen).

Built on NixOS, but nothing here needs Nix: it works on any distro that has the programs below.

![The desktop: bar, clocks and weather, shortcuts, system, connections, calendar, lyrics](screenshots/desktop.jpg)

| Launcher (Super+Space) | Popups |
|---|---|
| ![Typing in the launcher: actions, emoji, VPN locations, web search](screenshots/launcher.gif) | ![Calendar, player, quick settings, notifications and account popups](screenshots/popups.gif) |

**Wallpaper switch:** the new picture is sketched in, then coloured, and the whole desktop recolours to match.

![Switching wallpaper and back](screenshots/wallpaper.gif)

**Lock screen:** an Evangelion-style "signal board" with live clocks, weather, system meters, the player and your devices.

![The lock screen](screenshots/lock.jpg)

The boot menu in the same style: a GRUB theme, with the older system versions one level down.

| ![Boot menu](screenshots/boot-menu.jpg) | ![Boot menu: older versions](screenshots/boot-menu-versions.jpg) |
|---|---|

<details>
<summary>More screenshots</summary>

| | |
|---|---|
| ![Calendar popup](screenshots/calendar.jpg) Calendar | ![Player popup](screenshots/music.jpg) Player |
| ![Quick settings](screenshots/quick-settings.jpg) Quick settings | ![Notifications](screenshots/notifications.jpg) Notifications |
| ![Notification list grouped by app](screenshots/notification-center.jpg) Notification list | ![Wi-Fi popup](screenshots/wifi.jpg) Wi-Fi |
| ![Launcher: settings and actions](screenshots/launcher.jpg) Launcher | ![Launcher: calculator](screenshots/launcher-calc.jpg) Calculator |
| ![Launcher: emoji](screenshots/launcher-emoji.jpg) Emoji | ![Launcher: VPN locations](screenshots/launcher-vpn.jpg) VPN locations |
| ![Settings: appearance](screenshots/settings-appearance.jpg) Settings: appearance | ![Settings: power and idle](screenshots/settings-power.jpg) Settings: power |
| ![Wallpaper switcher](screenshots/wallpaper-switcher.jpg) Wallpaper switcher | ![Hermes / Claude side panel](screenshots/side-panel.jpg) Side panel |
| ![Account popup](screenshots/account.jpg) Account | ![Lock screen after the right password](screenshots/lock-granted.jpg) Lock screen: access granted |

</details>

The screenshots use demo mode (`qs ipc call settings set demo true`): made-up calendar, mail,
Wi-Fi names and devices.

## What's in it

| Folder | What |
|---|---|
| `quickshell/` | the whole shell; `shell.qml` lists every file and what it does |
| `hypr/` | Hyprland (**Lua config, Hyprland 0.57+**), hyprlock, and scripts: `lock` (the lock screen, hyprlock as fallback) and `idle-config` (writes hypridle's config from the idle settings) |
| `matugen/` | templates that recolour the shell, Hyprland, WezTerm, rofi and GTK from the wallpaper |
| `rofi/` | a "Spotlight"-style launcher with mode tabs |
| `wezterm/`, `starship/` | terminal and prompt |
| `aliases/` | zsh aliases and functions (loaded from `~/aliases`) |
| `waybar/`, `mako/` | an old fallback bar and notifications (not used by default) |
| `bin/setwall` | sets the wallpaper and recolours everything |
| `sddm-eva/` | an optional SDDM login screen matching the lock screen, and its status script |

### The shell
- **Bar:** workspaces with app icons, now playing, RAM, keyboard layout, volume, Wi-Fi,
  Bluetooth, battery, notifications, unread Gmail (when there is some), the clock (click: the
  calendar), and your picture (account popup) on the left.
- **Desktop widgets:**
  - one or two cities' clocks with a 48-hour forecast (Open-Meteo, saved for offline);
  - system (CPU, memory, NVIDIA asleep/awake, battery, power profile);
  - Tailscale and VPN switches;
  - a shortcuts card;
  - a calendar: the month with dots for days with events, and the chosen day's Google Calendar
    events (or what's coming up), saved for offline;
  - a draggable music controller;
  - synced lyrics that roll like a drum (LRCLIB, saved for offline).
- **Popups:**
  - player (cava visualiser, wavy seek bar, EasyEffects presets);
  - calendar (click the clock): the month and the chosen day's events from every Google account,
    with Join for Meet calls;
  - Wi-Fi, Bluetooth, volume, battery, unread mail per account;
  - notifications grouped by app, with Do not disturb and per-app mute;
  - Quick settings.
- **Settings window (Super+I):** Wi-Fi & VPN, Bluetooth, sound (devices, per-app volume,
  EasyEffects presets), notifications, keyboard & typing languages, appearance (wallpaper,
  typeface, lock glow, widgets), clocks & weather, accounts (connect / remove Google accounts,
  Hermes' MCP servers), power, about. Desktop settings changed there
  go to `~/.config/desktop/overrides.json`, on top of `settings.json`.
- **Overlays:**
  - launcher (Super+Space): apps, windows, switches and actions, a calculator, files, emoji,
    clipboard history and web searches in one box (`>` runs a command, `:` emoji, `f` files);
  - wallpaper switcher (Super+W): folders as tabs, Now vs New with the colours each would give, a tilting carousel;
  - picture picker;
  - cheat sheet (Super+/);
  - Alt+Tab window switcher.
- **Side panel (Super+A):** chats with [Hermes](https://github.com/NousResearch/hermes-agent) and
  Claude Code, with `/sessions` and `/new`, streaming, and Undo for file edits.
- **Lock screen:** an Evangelion-inspired "signal board", unlocked through PAM. Super+Escape,
  idle and sleep lock with it through `hypr/scripts/lock`, which falls back to hyprlock if the
  shell can't lock.
- **Wallpaper transition:** the new picture's outlines are drawn in, then its colours fill in
  (`quickshell/shaders/sketch.frag`).

## Install

1. **Programs:**
   - **core:** Hyprland 0.57+, Quickshell 0.3.2, matugen, rofi (+ rofi-calc, rofi-emoji, rofi-nerdy);
   - **tools:** WezTerm, starship, hypridle, hyprlock, jq, curl, NetworkManager (`nmcli`), PipeWire, playerctl, brightnessctl, grim, slurp, wl-clipboard, cliphist, libnotify (`notify-send`), cava;
   - **icons:** Papirus.

   Optional:
   - Tailscale; EasyEffects;
   - blueman and pavucontrol;
   - `hermes` and `claude` for the side panel;
   - `hermes` with its google-workspace skill for Google Calendar and Gmail (`quickshell/scripts/google`
     signs accounts in through it; tokens stay in `~/.hermes`);
   - `qt6.qtshadertools`, only to edit the shader.
2. **Fonts:**
   - Inter, Outfit, FiraCode Nerd Font;
   - for the lock screen: TeX Gyre Heros Cn (gyre-fonts), Shippori Mincho B1, Share Tech Mono.
3. **Copy the folders into `~/.config/`** (or symlink them), `aliases/` to `~/aliases`, and
   `bin/setwall` somewhere on your `PATH`.
4. **Settings:** copy `quickshell/settings.example.json` to `~/.config/desktop/settings.json` and
   change it. It sets:
   - your cities (one or two), picture folders, and where screenshots go;
   - your GPU's PCI address (for the asleep/awake row; `""` hides it);
   - the VPN connection prefix, the lock screen glow, and which widgets show;
   - the idle times (dim, lock, screen off, sleep) and the plain look in Saver mode (no blur, shadows or animations), both also in Settings → Power.

   Then run `~/.config/hypr/scripts/idle-config`: it writes `hypr/hypridle.conf` (not in the repo)
   and restarts hypridle. To keep it fresh, run it before hypridle starts, e.g. a systemd drop-in
   for hypridle.service with `ExecStartPre=-%h/.config/hypr/scripts/idle-config --no-restart`.

   Without the file you get sensible defaults.
5. **Colours:** run `setwall /path/to/a/picture` once. It makes the colour files (they aren't in
   the repo) and sets the wallpaper.
6. **Start:** log into Hyprland; `hypr/hyprland.lua` starts Quickshell (`qs -n -d`).
   - Restart the shell: Super+Shift+B.
   - Logs: `qs log`.

## Login screen (optional)

`sddm-eva/` is an SDDM theme (Qt 6) with the same "signal board" look as the lock screen. SDDM
can't read your home folder or run commands, so `sddm-eva/greeter-status` (run as root by a
timer) writes `/run/greeter-status.json` (battery, Tailscale device names and online state,
weather, meters) and copies `~/.face.icon` to `/run/greeter-face`.

1. Copy `sddm-eva/` to `/usr/share/sddm/themes/eva` and set `Current=eva` under `[Theme]` in
   your SDDM config. Add `GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1` under `[General]`.
2. Put your cities and GPU in `/etc/greeter/settings.json` (same keys as
   `quickshell/settings.example.json`), and run `greeter-status /etc/greeter/settings.json <you>`
   every minute as root (needs jq, curl, NetworkManager, tailscale).
3. Try it first without logging out: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/eva`.
   Glow: `glow=strong|soft|off` in `theme.conf`.

## Keys

Press **Super+/** for the full list. The essentials:

| Keys | |
|---|---|
| Super+Space | launcher (Super+Shift+Space: rofi) |
| Super+Return | terminal |
| Super+Q / F / V | close / fullscreen / float |
| Super+1…0, Super+Shift+1…0 | go to workspace / move window there |
| Alt+Tab | window switcher (hold Alt) |
| Super+M | minimize (Alt+Tab brings it back) |
| Super+W | wallpaper switcher |
| Super+A | Hermes / Claude side panel |
| Super+, | Quick settings |
| Super+I | Settings window |
| Super+N | notifications |
| Print / Shift+Print | screenshot region / screen |
| Middle-click a tray icon | quit that app |

## Notes

- `quickshell/Settings.qml` documents every setting; `Theme.qml` has one `typeface` setting with
  six font pairings.
- The lock screen uses the PAM service `hyprlock` (`/etc/pam.d/hyprlock`, installed with hyprlock).
- `hypr/hyprland.lua` puts some apps on fixed workspaces (browser 1, terminal 2, code 3, chat 4…):
  change those rules to suit your apps.
- Tested on NixOS unstable, on an AMD + NVIDIA laptop at 1920×1080.
