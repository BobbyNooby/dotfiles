//@ pragma UseQApplication
// Quickshell entry point: Hyprland starts it with `qs` (see hyprland.lua).
// Everything here reloads live when you save a file. Logs: `qs log -f`.
// Restart it completely: Super+Shift+B.
//
// The look follows the "Clean desktop" design (claude.ai design canvas "NixOS Desktop Preview").
//
// Files:
//   Theme.qml               colours (from matugen's colors.json), fonts, sizes
//   Icon.qml / Txt.qml / Toggle.qml / Clicky.qml   small building blocks (icons, text, switch, button)
//   SmoothWheel.qml         smooth mouse-wheel / touchpad scrolling for any scrolling list
//   Common.js               helpers several files share (battery time, Bluetooth icon, brightness, EasyEffects)
//   Bar.qml                 the top bar
//   DesktopWidgets.qml      clocks + weather, System, Connections, Calendar, lyrics, music controller
//   Wallpaper.qml           draws the wallpaper chosen with `setwall`
//   Popups.qml              which dropdown is open; Dropdown.qml is the base they share:
//     AccountPanel.qml (your picture; Avatar.qml draws it) MemoryPanel.qml (what uses the RAM) InputPanel.qml (typing language) MusicPanel.qml WifiPanel.qml BluetoothPanel.qml VolumePanel.qml BatteryPanel.qml NotificationCenter.qml
//     CalendarPanel.qml (click the clock: month + the day's Google events) MailPanel.qml (unread per account)
//   CalMonth.qml / CalDayList.qml   the month grid and the day's events, shared by the calendar
//                           popup and the desktop Calendar card
//   HermesPanel.qml         Super+A side panel (chat in Hermes.qml, scripts/ask)
//   WallpaperPicker.qml     Super+W: tabs, Now vs New with their colours, a tilting carousel
//   AvatarPicker.qml        account picture grid (ImageList.qml finds images, WallColors.qml previews colours)
//   LevelOsd.qml            volume / brightness indicator (`qs ipc call osd brightness`)
//   LockScreen.qml          the Eva 7 lock screen (EvaBoard.qml draws it, EvaStyle.qml + EvaTag.qml its look)
//                           `qs ipc call lock lock`; unlocks through PAM
//   Switcher.qml            Alt+Tab window switcher (hold Alt, Tab to step, let go to switch)
//   Launcher.qml            Super+Space search: apps, windows, actions, sums, files, emoji, web
//                           (LauncherRow.qml one line, LauncherLib.js matching + calculator, scripts/launcher-files)
//   CheatSheet.qml          Super + / : keys and aliases over everything (lists in Shortcuts.qml,
//                           aliases read by scripts/aliases; KeyList.qml draws a list)
//   Notifs.qml              notification daemon (replaces mako)
//   Input.qml               typing language (fcitx5): the bar's indicator, Ctrl+Space
//   NotificationPopups.qml  popups in the corner; NotificationCard.qml is one notification
//   ControlCenter.qml       Quick settings: tiles, volume + brightness, power mode (Super + ,)
//   Controls.qml            `qs ipc call controls toggle` for it
//   SettingsWindow.qml      Settings (Super+I): a page per topic, Set<Name>Page.qml each, built from
//                           SetPage/SetCard/SetRow/SetChoice/SetButton/SetField + OverrideNote.qml
//   data: Media (player + lyrics), Stats (CPU, memory, GPU), Weather, Net (Wi-Fi),
//         Vpn (Tailscale + Surfshark, the Connections card),
//         Gcal (Google accounts, calendar events, unread mail; cached for offline)
//   scripts/google          Google accounts for the shell and Hermes (accounts, events, unread,
//                           connect/disconnect; Settings → Accounts = SetAccountsPage.qml)
//   scripts/wifi-menu       network picker in rofi (for new secured networks)
//   scripts/ask             one question to Hermes or Claude Code, for the side panel
//   cava.conf               the player's visualiser
import QtQuick
import Quickshell

ShellRoot {
    // One wallpaper, widget layer and bar per monitor
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Wallpaper { modelData: perScreen.modelData }
            DesktopWidgets { modelData: perScreen.modelData }
            Bar { modelData: perScreen.modelData }
        }
    }

    AccountPanel {}
    MemoryPanel {}
    InputPanel {}
    MusicPanel {}
    WifiPanel {}
    BluetoothPanel {}
    VolumePanel {}
    BatteryPanel {}
    CalendarPanel {}
    MailPanel {}
    NotificationCenter {}
    NotificationPopups {}
    HermesPanel {}
    CheatSheet {}
    WallpaperPicker {}
    AvatarPicker {}
    Switcher {}
    Launcher {}
    LockScreen {}
    LevelOsd {}
    ControlCenter {}
    SettingsWindow {}
}
