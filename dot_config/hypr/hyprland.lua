-- vim: set foldmethod=marker foldlevel=0 nowrap:

local util = require("hyprland-util")

-- {{{ monitor

local icc_fn = "/home/falk/.local/share/color/profile.icc"
if util.file_exists(icc_fn) then
  hl.monitor({ output = 'eDP-1', mode = 'preferred', position = 'auto', scale = '1', icc=icc_fn })
else
  hl.monitor({ output = 'eDP-1', mode = 'preferred', position = 'auto', scale = '1', })
end
hl.monitor({ output = '',      mode = 'preferred', position = 'auto-center-up', scale = 'auto', })

-- }}}

-- {{{ variables

local mainMod = 'SUPER'
local menu    = 'hyprlauncher'

-- }}}

-- {{{ autostart

hl.on('hyprland.start', function()
    hl.config({misc = {initial_workspace_tracking = 0}})
    -- System
    hl.exec_cmd('dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_CLASS')
    hl.exec_cmd('systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_CLASS')
    hl.exec_cmd('systemctl --user start hyprland-session.target')
    hl.exec_cmd('/usr/lib/pam_kwallet_init')
    hl.exec_cmd('hypridle')
    hl.exec_cmd('hyprpaper')
    hl.exec_cmd('hyprsunset')
    hl.exec_cmd('hyprpm reload')
    hl.exec_cmd("hyprlauncher -d")
    hl.exec_cmd('swaync')
    hl.exec_cmd('swayosd-server')
    hl.exec_cmd('blueman-applet')
    hl.exec_cmd('/usr/lib/hyprpolkitagent')
    hl.exec_cmd('wl-paste --type text --watch cliphist store')
    hl.exec_cmd('wl-paste --type image --watch cliphist store')
    hl.exec_cmd('udiskie')
    hl.exec_cmd('~/.local/bin/battery-daemon')
    hl.exec_cmd('~/.local/bin/run-minibar.sh')
    hl.exec_cmd('wvkbd-deskintl --hidden')
    hl.config({misc = {initial_workspace_tracking = 1}})

    -- Apps
    hl.exec_cmd('kitty', {workspace = '2 silent'})
    hl.exec_cmd('helium-browser', {workspace = '1'})
end)

hl.on('hyprland.shutdown', function()
    hl.exec_cmd('systemctl --user stop hyprland-session.target')
end)

-- }}}

-- {{{ env

hl.env('XCURSOR_SIZE',    '24')
hl.env('HYPRCURSOR_SIZE', '24')

-- }}}

-- {{{ general

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        resize_on_border = false,
        allow_tearing = false,
        layout = 'dwindle',

        col = {
            active_border = {
                colors = { 'rgba(33ccffee)', 'rgba(00ff99ee)' },
                angle = 45,
            },
            inactive_border = 'rgba(595959aa)',
        },
    },
})

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

-- }}}

-- {{{ decoration / animations

hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 'rgba(1a1a1aee)',
        },

        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
})

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve('easeOutQuint',   { type = 'bezier', points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve('easeInOutCubic', { type = 'bezier', points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve('linear',         { type = 'bezier', points = { { 0, 0 },       { 1, 1 } }    })
hl.curve('almostLinear',   { type = 'bezier', points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve('quick',          { type = 'bezier', points = { { 0.15, 0 },    { 0.1, 1 } }  })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71, dampening = 16 })

hl.animation({ leaf = 'global',        enabled = false, speed = 10,   bezier = 'default' })
hl.animation({ leaf = 'border',        enabled = false, speed = 5.39, bezier = 'easeOutQuint' })
hl.animation({ leaf = 'windows',       enabled = false, speed = 4.79, spring = 'easy' })
hl.animation({ leaf = 'windowsIn',     enabled = false, speed = 4.1,  spring = 'easy',         style = 'popin 87%' })
hl.animation({ leaf = 'windowsOut',    enabled = false, speed = 1.49, bezier = 'linear',       style = 'popin 87%' })
hl.animation({ leaf = 'fadeIn',        enabled = false, speed = 1.73, bezier = 'almostLinear' })
hl.animation({ leaf = 'fadeOut',       enabled = false, speed = 1.46, bezier = 'almostLinear' })
hl.animation({ leaf = 'fade',          enabled = false, speed = 3.03, bezier = 'quick' })
hl.animation({ leaf = 'layers',        enabled = false, speed = 3.81, bezier = 'easeOutQuint' })
hl.animation({ leaf = 'layersIn',      enabled = false, speed = 4,    bezier = 'easeOutQuint', style = 'fade' })
hl.animation({ leaf = 'layersOut',     enabled = false, speed = 1.5,  bezier = 'linear',       style = 'fade' })
hl.animation({ leaf = 'fadeLayersIn',  enabled = false, speed = 1.79, bezier = 'almostLinear' })
hl.animation({ leaf = 'fadeLayersOut', enabled = false, speed = 1.39, bezier = 'almostLinear' })
hl.animation({ leaf = 'workspaces',    enabled = false, speed = 1.94, bezier = 'almostLinear', style = 'slide' })
hl.animation({ leaf = 'workspacesIn',  enabled = false, speed = 1.21, bezier = 'almostLinear', style = 'slide' })
hl.animation({ leaf = 'workspacesOut', enabled = false, speed = 1.94, bezier = 'almostLinear', style = 'slide' })
hl.animation({ leaf = 'zoomFactor',    enabled = false, speed = 7,    bezier = 'quick' })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = 'master',
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

-- }}}

-- {{{ misc

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

-- }}}

-- {{{ input

hl.config({
    input = {
        kb_layout = 'us',
        kb_variant = '',
        kb_model = '',
        kb_options = 'caps:escape,compose:ralt',
        kb_rules = '',
        repeat_rate = 35,
        repeat_delay = 300,
        follow_mouse = 2,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = 'horizontal',
    action = 'workspace',
})

hl.gesture({ fingers = 3, direction = "down", action = "close" })
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "up", mods = "SUPER", action = "float" })

hl.device({
    name = 'epic-mouse-v1',
    sensitivity = -0.5,
})

-- }}}

-- {{{ binds

hl.bind(mainMod .. ' + Return',    hl.dsp.exec_cmd('kitty --directory "$(~/.local/bin/terminal-cwd.sh)"'), { description = 'Open terminal' })
hl.bind(mainMod .. ' + X',         hl.dsp.window.close(),                                                  { description = 'Close active window' })
hl.bind(
    mainMod .. ' + M',
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"),
    { description = 'Close hyprland' }
)
hl.bind(mainMod .. ' + E',         hl.dsp.exec_cmd('thunar'),                                           { description = 'Open file explorer' })
hl.bind(mainMod .. ' + D',         hl.dsp.exec_cmd('~/.local/bin/dark-mode.sh'),                        { description = 'Toggle dark/light mode' })
hl.bind(mainMod .. ' + SHIFT + N', hl.dsp.exec_cmd('nm-connection-editor'),                             { description = 'Open NM Connection Editor' })
hl.bind(mainMod .. ' + N',         hl.dsp.exec_cmd('kitty --class kitty_impala --hold impala'),         { description = 'Open Impala wifi TUI' })
hl.bind(mainMod .. ' + R',         hl.dsp.exec_cmd('qalculate-gtk'),                                    { description = 'Open Qalculate' })
hl.bind(mainMod .. ' + I',         hl.dsp.exec_cmd('kitty --class kitty_nmcli nmcli'),                  { description = 'Show network status' })
hl.bind(mainMod .. ' + B',         hl.dsp.exec_cmd('blueman-manager'),                                  { description = 'Open bluetooth manager' })
hl.bind(mainMod .. ' + A',         hl.dsp.exec_cmd('hyprpwcenter'),                                     { description = 'Open audio manager' })
hl.bind(mainMod .. ' + F',         hl.dsp.window.float({ action = 'toggle' }),                          { description = 'Toggle floating window' })
hl.bind(mainMod .. ' + SHIFT + F', hl.dsp.window.fullscreen(),                                          { description = 'Toggle full screen' })
hl.bind(mainMod .. ' + G',         hl.dsp.group.toggle(),                                               { description = 'Toggle grouping (tabbed)' })
hl.bind(mainMod .. ' + SHIFT + G', hl.dsp.exec_cmd('~/.local/bin/workspace_to_group.sh'),               { description = 'Add all windows to group' })
hl.bind(mainMod .. ' + Tab',       hl.dsp.group.next(),                                                 { description = 'Change tab in group' })
hl.bind(mainMod .. ' + Space',     hl.dsp.exec_cmd(menu),                                               { description = 'Open launcher' })
hl.bind(mainMod .. ' + P',         hl.dsp.window.pseudo(),                                              { description = 'Toggle pseudo tiling' })
hl.bind(mainMod .. ' + J',         hl.dsp.layout('togglesplit'),                                        { description = 'Toggle window splitting' })
hl.bind(mainMod .. ' + H',         hl.dsp.exec_cmd('kitty --class kitty_btop --hold btop'),             { description = 'Open btop' })
hl.bind(mainMod .. ' + L',         hl.dsp.exec_cmd('~/.local/bin/lock-session.sh'),                     { description = 'Lock session' })
hl.bind('Print',                   hl.dsp.exec_cmd('~/.local/bin/screenshot-menu -r -c'),               { description = 'Take screenshot' })
hl.bind(mainMod .. ' + Page_Up',   hl.dsp.global(':_toggle_recording'),                                 { description = 'Toggle OBS recording' })
hl.bind(mainMod .. ' + V',         hl.dsp.exec_cmd('~/.local/bin/cliphist_show.sh'),                    { description = 'Open clipboard history' })
hl.bind(mainMod .. ' + K',         hl.dsp.exec_cmd('~/.local/bin/get_binds.sh | hyprlauncher --dmenu'), { description = 'Show keybinds' })
hl.bind(mainMod .. ' + SHIFT + K', hl.dsp.exec_cmd('pkill -RTMIN -x wvkbd-deskintl'),                   { description = 'Toggle screen keyboard' })

hl.bind(mainMod .. ' + ALT + I',   hl.dsp.exec_cmd('~/.local/bin/idle-menu',                            { float = true, center = true, stay_focused = true }), { description = 'Toggle hypridle' })
hl.bind(mainMod .. ' + SHIFT + L', hl.dsp.exec_cmd('~/.local/bin/lock-menu',                            { float = true, center = true, stay_focused = true }), { description = 'Open power menu' })
hl.bind('SHIFT + Print',           hl.dsp.exec_cmd('~/.local/bin/screenshot-menu',                      { float = true, center = true, stay_focused = true }), { description = 'Take screenshot' })
hl.bind('ALT + Print',             hl.dsp.exec_cmd('~/.local/bin/screenrecord-menu',                    { float = true, center = true, stay_focused = true }), { description = 'Take screen recording' })
hl.bind(mainMod .. ' + SHIFT + P', hl.dsp.exec_cmd('~/.local/bin/power-menu',                           { float = true, center = true, stay_focused = true }), { description = 'Open power mode menu' })

hl.bind(mainMod .. ' + Left',    hl.dsp.focus({ direction = 'left' }),  { description = 'Move focus left' })
hl.bind(mainMod .. ' + Right',   hl.dsp.focus({ direction = 'right' }), { description = 'Move focus right' })
hl.bind(mainMod .. ' + Up',      hl.dsp.focus({ direction = 'up' }),    { description = 'Move focus up' })
hl.bind(mainMod .. ' + Down',    hl.dsp.focus({ direction = 'down' }),  { description = 'Move focus down' })
hl.bind(mainMod .. ' + ALT + H', hl.dsp.focus({ direction = 'left' }),  { description = 'Move focus left' })
hl.bind(mainMod .. ' + ALT + L', hl.dsp.focus({ direction = 'right' }), { description = 'Move focus right' })
hl.bind(mainMod .. ' + ALT + K', hl.dsp.focus({ direction = 'up' }),    { description = 'Move focus up' })
hl.bind(mainMod .. ' + ALT + J', hl.dsp.focus({ direction = 'down' }),  { description = 'Move focus down' })

hl.bind(mainMod .. ' + SHIFT + Left',  hl.dsp.window.move({ direction = 'left' }),  { description = 'Move window left' })
hl.bind(mainMod .. ' + SHIFT + Right', hl.dsp.window.move({ direction = 'right' }), { description = 'Move window right' })
hl.bind(mainMod .. ' + SHIFT + Up',    hl.dsp.window.move({ direction = 'up' }),    { description = 'Move window up' })
hl.bind(mainMod .. ' + SHIFT + Down',  hl.dsp.window.move({ direction = 'down' }),  { description = 'Move window down' })

for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. ' + ' .. key,         hl.dsp.focus({ workspace = i }),         { description = 'Switch to workspace ' .. i })
    hl.bind(mainMod .. ' + SHIFT + ' .. key, hl.dsp.window.move({ workspace = i }),   { description = 'Move to workspace ' .. i })
end

hl.bind(mainMod .. ' + Grave', hl.dsp.focus({ workspace = 'previous' }), { description = 'Switch to previous workspace' })

hl.bind(mainMod .. ' + SHIFT + Period', hl.dsp.workspace.move({ monitor = '+1' }), { description = 'Move current workspace to next monitor' })
hl.bind(mainMod .. ' + SHIFT + Comma',  hl.dsp.workspace.move({ monitor = '-1' }), { description = 'Move current workspace to previous monitor' })

hl.bind(mainMod .. ' + S',         hl.dsp.workspace.toggle_special('magic'),               { description = 'Toggle special workspace' })
hl.bind(mainMod .. ' + SHIFT + S', hl.dsp.window.move({ workspace = 'special:magic' }),   { description = 'Move to magic workspace' })

hl.bind(mainMod .. ' + mouse_down',hl.dsp.focus({ workspace = 'e+1' }), { description = 'Scroll workspaces' })
hl.bind(mainMod .. ' + mouse_up',  hl.dsp.focus({ workspace = 'e-1' }), { description = 'Scroll workspaces' })

hl.bind(mainMod .. ' + mouse:272', hl.dsp.window.drag(),   { mouse = true, description = 'Move with mouse' })
hl.bind(mainMod .. ' + CONTROL_L', hl.dsp.window.drag(),   { mouse = true, description = 'Move with mouse' })
hl.bind(mainMod .. ' + mouse:273', hl.dsp.window.resize(), { mouse = true, description = 'Resize with mouse' })
hl.bind(mainMod .. ' + ALT_L',     hl.dsp.window.resize(), { mouse = true, description = 'Resize with mouse' })

hl.bind('XF86AudioRaiseVolume',  hl.dsp.exec_cmd('wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+'),       { locked = true, repeating = true, description = 'Volume raise' })
hl.bind('XF86AudioLowerVolume',  hl.dsp.exec_cmd('wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'),       { locked = true, repeating = true, description = 'Volume lower' })
hl.bind('XF86AudioMute',         hl.dsp.exec_cmd('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'), { locked = true, repeating = true, description = 'Output mute toggle' })
hl.bind('XF86AudioMicMute',      hl.dsp.exec_cmd('wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'),  { locked = true, repeating = true, description = 'Input mute toggle' })
hl.bind('XF86MonBrightnessUp',   hl.dsp.exec_cmd('swayosd-client --brightness raise'),          { locked = true, repeating = true, description = 'Brightness raise' })
hl.bind('XF86MonBrightnessDown', hl.dsp.exec_cmd('swayosd-client --brightness lower'),          { locked = true, repeating = true, description = 'Brightness lower' })

hl.bind('XF86AudioNext',  hl.dsp.exec_cmd('playerctl next'),       { locked = true, description = 'Play next' })
hl.bind('XF86AudioPause', hl.dsp.exec_cmd('playerctl play-pause'), { locked = true, description = 'Pause' })
hl.bind('XF86AudioPlay',  hl.dsp.exec_cmd('playerctl play-pause'), { locked = true, description = 'Play' })
hl.bind('XF86AudioPrev',  hl.dsp.exec_cmd('playerctl previous'),   { locked = true, description = 'Play prev' })

hl.bind('SUPER + Equal', hl.dsp.window.resize({ x = 40, y = 40, relative = true }),   { description = 'Stretch active window' })
hl.bind('SUPER + Minus', hl.dsp.window.resize({ x = -40, y = -40, relative = true }), { description = 'Contract active window' })

-- }}}

-- {{{ windowrules

hl.window_rule({
    name = 'suppress-maximize-events',
    match = { class = '.*' },
    suppress_event = 'maximize',
})

hl.window_rule({
    name = 'fix-xwayland-drags',
    match = {
        class = '^$',
        title = '^$',
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = 'move-hyprland-run',
    match = { class = 'hyprland-run' },
    move = '20 monitor_h-120',
    float = true,
})

hl.window_rule({
    name = 'blueman-manager',
    match = { class = 'blueman-manager' },
    float = true,
    center = true,
    size = 'monitor_w*0.5 monitor_h*0.5',
})
hl.window_rule({
    name = 'nm-connection-editor',
    match = { class = 'nm-connection-editor' },
    float = true,
    center = true,
    size = 'monitor_w*0.25 monitor_h*0.5',
})
hl.window_rule({
    name = 'kitty-impala',
    match = { class = 'kitty_impala' },
    float = true,
    center = true,
    size = 'monitor_w*0.5 monitor_h*0.75',
})
hl.window_rule({
    name = 'kitty-nmcli',
    match = { class = 'kitty_nmcli' },
    float = true,
    center = true,
    size = 'monitor_w*0.5 monitor_h*0.8',
})
hl.window_rule({
    name = 'kitty-btop',
    match = { class = 'kitty_btop' },
    float = true,
    center = true,
    size = 'monitor_w*0.75 monitor_h*0.75',
})
hl.window_rule({
    name = 'firefox-pip',
    match = { class = 'firefox', title = 'Picture-in-Picture' },
    float = true,
    size = 'monitor_w*0.25 monitor_h*0.25',
    pin = true,
})
hl.window_rule({
    name = 'localsend',
    match = { class = 'localsend' },
    float = true,
    size = 'monitor_w*0.25 monitor_h*0.5',
})
hl.window_rule({
    name = 'satty',
    match = { class = 'com.gabm.satty' },
    float = true,
})
hl.window_rule({
    name = 'kitty-status',
    match = { class = 'kitty_status' },
    float = true,
    center = true,
    size = '350 170',
})
hl.window_rule({
    name = 'qalculate-gtk',
    match = { class = 'qalculate-gtk' },
    float = true,
    center = true,
    size = 'monitor_w*0.5 monitor_h*0.5',
})

-- }}}

-- {{{ plugins

-- }}}
