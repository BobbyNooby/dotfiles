-- WezTerm config (macOS-style defaults). Reloads automatically on save.
-- Reference: https://wezterm.org/config/files.html
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- WezTerm's native Wayland mode has a history of crashes and scaling bugs on
-- Hyprland (especially with NVIDIA), so it runs through XWayland here. That's
-- solid at scale 1; try `true` if you use fractional scaling and it's blurry.
config.enable_wayland = false

-- ---- colours ----
-- matugen writes colors/matugen.toml from the wallpaper (run `setwall <image>`).
-- Until that file exists, Tokyo Night is used.
local matugen = wezterm.config_dir .. "/colors/matugen.toml"
config.color_scheme_dirs = { wezterm.config_dir .. "/colors" }
local f = io.open(matugen, "r")
if f then
  f:close()
  config.color_scheme = "Matugen"
  -- reload when a new wallpaper rewrites the scheme
  wezterm.add_to_config_reload_watch_list(matugen)
else
  config.color_scheme = "Tokyo Night Storm"
end

-- ---- font and window (macOS-style values, font size converted) ----
config.font = wezterm.font("FiraCode Nerd Font Mono")
config.font_size = 10.0 -- 13 on macOS (macOS counts 72 dpi, Linux 96, so 13 there ≈ 10 here)
config.line_height = 1.2
-- Battery look (hypr/scripts/saver-look writes this file in Saver mode): no blur behind the
-- window then, so the glass would be hard to read: go nearly solid. Reloads when it changes.
local saver_file = wezterm.home_dir .. "/.local/state/desktop/saver-look"
wezterm.add_to_config_reload_watch_list(saver_file)
local f = io.open(saver_file)
local plain = f ~= nil and f:read("*l") == "on"
if f then f:close() end
config.window_background_opacity = plain and 0.96 or 0.75 -- see-through "glass": Hyprland blurs what's behind (decoration.blur)
config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
config.window_decorations = "NONE" -- Hyprland draws the borders; no title bar needed
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"
config.scrollback_lines = 20000

-- Tab bar always shown, as on macOS. New tab: Ctrl+Shift+T (Linux's Cmd+T).
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false

-- Splits and sessions: use tmux (prefix Ctrl+A).

-- Shift+Insert pastes the clipboard (WezTerm's default is the primary selection), so it pastes
-- the same thing as in every other app, including dictation (Voxtype pastes with Shift+Insert).
config.keys = {
  { key = "Insert", mods = "SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
}

return config
