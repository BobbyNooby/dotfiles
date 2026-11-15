-- Hyprland config (Lua, Hyprland 0.57+).
-- Based on Hyprland's official example config. Full reference: https://wiki.hypr.land/configuring/
-- Save this file and Hyprland reloads it instantly. Errors show as a banner at the top of the screen.
--
-- Colours: matugen writes colors.lua (next to this file) from the wallpaper; it's loaded
-- under LOOK AND FEEL. The border colours written here are only the fallback (Tokyo Night).

------------------
---- MONITORS ----
------------------

-- Every monitor at its preferred resolution. List yours with `hyprctl monitors`, e.g.
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1, -- "auto" chose 1.5 on the 1920x1080 panel (eDP-1): too big. 1.25 if 1 is too small
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "wezterm"
local fileManager = "nautilus"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -n -d") -- Quickshell: bar, wallpaper, desktop widgets, notifications (-n: never a second copy)
    -- Fallback if Quickshell breaks: comment out "qs" above and use these two instead
    -- hl.exec_cmd("waybar")
    -- hl.exec_cmd("mako")
    -- hypridle: started by its systemd user service (not here: that ran it twice)
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-paste --watch cliphist store") -- clipboard history
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Which GPU Hyprland draws on (AQ_DRM_DEVICES = the AMD iGPU) is set in hosts/roxy/gpu.nix,
-- so it only switches on once the card IDs are filled in there.


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 12,

        border_size = 2,

        col = {
            -- blue → purple gradient on the focused window
            active_border   = { colors = {"rgba(7aa2f7ee)", "rgba(bb9af7ee)"}, angle = 45 },
            inactive_border = "rgba(3b4261aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 3,
            color        = 0xee11111b,
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Wallpaper colours from matugen (colors.lua, written by `setwall`). pcall: if the file
-- doesn't exist yet, the fallback colours above stay and nothing breaks.
pcall(require, "colors")

-- Blur behind the see-through Quickshell panels and rofi. ignore_alpha skips the fully
-- transparent parts (the gap above the bar, rounded corners).
hl.layer_rule({
    name         = "blur-shell",
    match        = { namespace = "^(qs-bar|qs-widgets|qs-notifications|qs-popup|qs-hermes|qs-switcher|qs-cheatsheet|qs-control-center|rofi)$" },
    blur         = true,
    ignore_alpha = 0.2,
})

-- Animation curves and timings (from the official example)
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,     -- Quickshell draws the wallpaper
        disable_hyprland_logo   = true,
        -- If the lock screen crashes while locked, a new one may take over (recovery: from a
        -- text console, `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`)
        allow_session_lock_restore = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 to 1.0, 0 = unchanged

        touchpad = {
            natural_scroll = true,
            scroll_factor  = 0.5, -- touchpad scroll speed (1.0 = default; lower = slower)
        },
    },
})

-- Three-finger swipe to switch workspace (laptop)
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("hyprlock"))
-- TESTING the new Eva lock screen (dotfiles/quickshell/LockScreen.qml). hyprlock stays on
-- Super+Escape and in hypridle until the new one is confirmed to unlock properly.
hl.bind(mainMod .. " + CTRL + Escape", hl.dsp.exec_cmd("qs ipc call lock lock"))

-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))
-- Minimize (Hyprland has none): hide the window on a special workspace instead of closing it.
-- Get it back with Alt+Tab (minimized windows are listed there).
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/minimize"))

-- Log out
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Alt+Tab: Quickshell's window switcher (dotfiles/quickshell/Switcher.qml). Hold Alt and press
-- Tab to step through your windows, most recent first (Shift+Tab goes back); letting go of Alt
-- jumps to the highlighted window on whatever workspace it's on. The release bind is
-- "transparent" so Alt still reaches apps normally.
hl.bind("ALT + TAB",         hl.dsp.exec_cmd("qs ipc call switcher next"), { repeating = true })
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("qs ipc call switcher prev"), { repeating = true })
hl.bind("ALT + ALT_L",       hl.dsp.exec_cmd("qs ipc call switcher commit"), { release = true, transparent = true })


-- Move focus with mainMod + h/j/k/l (Vim keys) or the arrow keys
local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(directions) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
end

-- Switch workspaces with mainMod + [0-9]
-- Move the active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad workspace that slides over everything
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces with mainMod + mouse wheel
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + left/right mouse drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots: a region (Print) or the whole screen (Shift + Print). Both are saved to your
-- screenshot folder (settings.nix desktop.folders.screenshotSave, read from
-- ~/.config/desktop/settings.json when the key is pressed) AND copied to the clipboard, with a
-- notification. Esc cancels a region.
local shot = 'd=$(jq -r ".folders.screenshotSave // \\"Pictures/Screenshots\\"" ~/.config/desktop/settings.json 2>/dev/null); '
    .. 'case "$d" in /*) ;; *) d="$HOME/${d#\\~/}" ;; esac; '
    .. 'mkdir -p "$d" && f="$d/screenshot-$(date +%F_%H-%M-%S).png" && '
local done = ' "$f" && wl-copy < "$f" && notify-send -a Screenshot -i "$f" Screenshot "Saved and copied: $f"'
hl.bind("Print",         hl.dsp.exec_cmd(shot .. 'grim -g "$(slurp)"' .. done))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(shot .. 'grim' .. done))

-- Control Center: Wi-Fi, Bluetooth, sound, power mode, brightness... (Cmd + , on the Mac)
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("qs ipc call controls toggle"))

-- Clipboard history picker
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p clipboard | cliphist decode | wl-copy"))

-- Quickshell: restart it, notification list, do not disturb, pick a wallpaper
-- (`qs kill` stops one copy at a time: keep going until none is left, so a restart never
-- leaves two shells running, which makes `qs ipc` calls like the lock hang)
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("for i in 1 2 3 4 5; do qs kill >/dev/null 2>&1 || break; done; qs -n -d"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("qs ipc call notifs toggleCenter"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("qs ipc call notifs toggleDnd"))
hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd("qs ipc call hermes toggle")) -- Hermes side panel
hl.bind(mainMod .. " + slash",     hl.dsp.exec_cmd("qs ipc call cheatsheet toggle")) -- keys + aliases cheat sheet
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("qs ipc call wallpicker toggle")) -- wallpaper switcher (WallpaperPicker.qml); `setwall` alone is the rofi fallback

-- Dictation (Voxtype, home/voxtype.nix): hold Super+Z and speak, let go to type the text at the
-- cursor. Super+Shift+Z throws the recording away. (Super+V = float, Super+Escape = lock: taken.)
hl.bind(mainMod .. " + Z",         hl.dsp.exec_cmd("voxtype record start"))
hl.bind(mainMod .. " + Z",         hl.dsp.exec_cmd("voxtype record stop"), { release = true })
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("voxtype record cancel"))

-- More rofi menus: emoji, calculator, power menu
hl.bind(mainMod .. " + period",         hl.dsp.exec_cmd("rofi -show emoji"))
hl.bind(mainMod .. " + C",              hl.dsp.exec_cmd("rofi -show calc -modi calc -no-show-match -no-sort"))
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("rofi -show power-menu -modi power-menu:rofi-power-menu"))

-- Volume, brightness and media keys. Media keys go to Spotify first: Spotifast also lists
-- itself as a player while it remote-controls Spotify, but ignores the keys.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl -p spotify,%any next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl -p spotify,%any play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl -p spotify,%any play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl -p spotify,%any previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Ignore apps asking to maximise themselves
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland apps
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- ---- Apps on their own workspaces (the Mac's AeroSpace layout) ----
-- 1 browser · 2 terminal · 3 code · 4 chat (tabbed) · 5 notes · 6 music · 7 mail · 8 anything else · 9 VPN
-- Rules only apply when a window opens, so already-open windows stay where they are.
-- Check a window's class with `hyprctl clients`.
local function on_workspace(name, class, ws)
    hl.window_rule({ name = name, match = { class = class }, workspace = tostring(ws) })
end
on_workspace("ws1-browser", "^microsoft-edge$",              1)
on_workspace("ws2-term",    "^org\\.wezfurlong\\.wezterm$",  2)
on_workspace("ws3-code",    "^dev\\.zed\\.Zed$",             3)
on_workspace("ws4-chat",    "^(discord|[Ss]lack)$",          4)
on_workspace("ws5-notes",   "^(obsidian|md\\.obsidian\\.Obsidian)$", 5)
on_workspace("ws6-music",   "^([Ss]potify|[Ss]potifast|rocks\\.spotifast\\.Spotifast)$", 6)
on_workspace("ws8-files",   "^org\\.gnome\\.Nautilus$",      8)
on_workspace("ws9-vpn",     "^(Surfshark|surfshark|com\\.surfshark\\.Surfshark)$", 9)
-- 7 mail: Outlook/WhatsApp web apps get their own class once installed as Edge apps; add them then.

-- Chat apps open as tabs of one group (the Mac's accordion). OFF for now: with only Discord
-- installed, a group of one just costs 21px of height for a single-tab tab bar, so Discord
-- wasn't filling the screen. Uncomment once Slack is actually here.
-- hl.window_rule({ name = "chat-tabbed", match = { class = "^(discord|[Ss]lack)$" }, group = "set" })

-- Small utility windows float instead of tiling
hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|.blueman-manager-wrapped)$" },
    float = true,
})
