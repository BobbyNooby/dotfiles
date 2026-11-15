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
config.window_background_opacity = 0.75 -- see-through "glass": Hyprland blurs what's behind (decoration.blur)
config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
config.window_decorations = "NONE" -- Hyprland draws the borders; no title bar needed
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"
config.scrollback_lines = 20000

-- Tab bar always shown, as on macOS. New tab: Ctrl+Shift+T (Linux's Cmd+T).
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false

-- Splits and sessions: use tmux (prefix Ctrl+A).

return config
