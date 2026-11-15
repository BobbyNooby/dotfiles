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
//   Bar.qml                 the top bar
//   DesktopWidgets.qml      clocks + weather, System, Connections, lyrics, music controller
//   Wallpaper.qml           draws the wallpaper chosen with `setwall`
//   Popups.qml              which dropdown is open; Dropdown.qml is the base they share:
//     AccountPanel.qml (your picture; Avatar.qml draws it) MemoryPanel.qml (what uses the RAM) MusicPanel.qml WifiPanel.qml BluetoothPanel.qml VolumePanel.qml BatteryPanel.qml NotificationCenter.qml
//   HermesPanel.qml         Super+A side panel (chat in Hermes.qml, scripts/ask)
//   WallpaperPicker.qml     Super+W: tabs, Now vs New with their colours, a tilting carousel
//   AvatarPicker.qml        account picture grid (ImageList.qml finds images, WallColors.qml previews colours)
//   LevelOsd.qml            volume / brightness indicator (`qs ipc call osd brightness`)
//   LockScreen.qml          the Eva 7 lock screen (EvaBoard.qml draws it, EvaStyle.qml + EvaTag.qml its look)
//                           `qs ipc call lock lock`; unlocks through PAM
//   Switcher.qml            Alt+Tab window switcher (hold Alt, Tab to step, let go to switch)
//   CheatSheet.qml          Super + / : keys and aliases over everything (lists in Shortcuts.qml,
//                           aliases read by scripts/aliases; KeyList.qml draws a list)
//   Notifs.qml              notification daemon (replaces mako)
//   NotificationPopups.qml  popups in the corner; NotificationCard.qml is one notification
//   ControlCenter.qml       Quick settings: tiles, volume + brightness, power mode (Super + ,)
//   Controls.qml            `qs ipc call controls toggle` for it
//   data: Media (player + lyrics), Stats (CPU, memory, GPU), Weather, Net (Wi-Fi),
//         Vpn (Tailscale + Surfshark, the Connections card)
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
    MusicPanel {}
    WifiPanel {}
    BluetoothPanel {}
    VolumePanel {}
    BatteryPanel {}
    NotificationCenter {}
    NotificationPopups {}
    HermesPanel {}
    CheatSheet {}
    WallpaperPicker {}
    AvatarPicker {}
    Switcher {}
    LockScreen {}
    LevelOsd {}
    ControlCenter {}
}
