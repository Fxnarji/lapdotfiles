-- Ported from github.com/fxnarji/dotfiles .config/hypr/modules/bindings.conf
-- (app-specific binds like Blender/OBS/Ferdium dropped).

local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "quickshell:launcher"
local mainMod     = "SUPER"

local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts)
end

-- Apps
bind(mainMod .. " + G",     hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager))
bind("ALT + SPACE",         hl.dsp.global(menu))
bind(mainMod .. " + A",     hl.dsp.global("quickshell:audio"))
bind(mainMod .. " + L",     hl.dsp.exec_cmd("hyprlock"))
bind(mainMod .. " + N",     hl.dsp.global("quickshell:notifications"))
bind(mainMod .. " + B",     hl.dsp.global("quickshell:bluetooth"))
bind(mainMod .. " + W",     hl.dsp.global("quickshell:wifi"))
bind(mainMod .. " + K",     hl.dsp.global("quickshell:keyboard"))
bind(mainMod .. " + V",     hl.dsp.global("quickshell:clipboard"))
bind(mainMod .. " + C", hl.dsp.global("quickshell:calview"))
bind(mainMod .. " + SHIFT + C", hl.dsp.global("quickshell:calendar"))
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
bind(mainMod .. " + SHIFT + D", hl.dsp.global("quickshell:wallpaper"))
bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))

-- Windows
bind(mainMod .. " + X",     hl.dsp.window.close())
bind(mainMod .. " + F",     hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. " + P",     hl.dsp.window.pseudo())
bind(mainMod .. " + J",     hl.dsp.layout("togglesplit"))
bind(mainMod .. " + SPACE", hl.dsp.window.fullscreen())

-- Focus and move with arrows
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(mainMod .. " + " .. dir,           hl.dsp.focus({ direction = dir }))
    bind(mainMod .. " + SHIFT + " .. dir,   hl.dsp.window.move({ direction = dir }))
end

-- Workspaces 1-10
for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
local held = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      held)
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     held)
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   held)
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  held)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  held)

bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
