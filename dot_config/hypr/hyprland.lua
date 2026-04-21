-- vim: set foldmethod=marker foldlevel=0 nowrap:

-- {{{ monitor

hl.monitor({ output = 'eDP-1', mode = 'preferred', position = 'auto',           scale = '1',    })
hl.monitor({ output = '',      mode = 'preferred', position = 'auto-center-up', scale = 'auto', })

-- }}}

-- {{{ variables

local mainMod = 'SUPER'
local menu    = 'hyprlauncher'

-- }}}

-- {{{ autostart

-- System
hl.exec_once('dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_CLASS')
hl.exec_once('systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_CLASS')
hl.exec_once('hypridle')
hl.exec_once('hyprpaper')
hl.exec_once('hyprsunset')
hl.exec_once('hyprpm reload')
hl.exec_once('hyprlauncher -d')
hl.exec_once('swaync')
hl.exec_once('swayosd-server')
hl.exec_once('blueman-applet')
hl.exec_once('systemctl --user start hyprpolkitagent.service')
hl.exec_once('wl-paste --type text --watch cliphist store')
hl.exec_once('wl-paste --type image --watch cliphist store')
hl.exec_once('udiskie')
hl.exec_once('~/.local/bin/battery_notify.sh')
hl.exec_once('~/.local/bin/charger_notify.sh')
hl.exec_once('~/.local/bin/run-minibar.sh')

-- Apps
hl.exec_once('firefox')
hl.exec_once('[workspace 2 silent] kitty')

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

hl.animation({ leaf = 'global',        enabled = true, speed = 10,   bezier = 'default' })
hl.animation({ leaf = 'border',        enabled = true, speed = 5.39, bezier = 'easeOutQuint' })
hl.animation({ leaf = 'windows',       enabled = true, speed = 4.79, bezier = 'easeOutQuint' })
hl.animation({ leaf = 'windowsIn',     enabled = true, speed = 4.1,  bezier = 'easeOutQuint', style = 'popin 87%' })
hl.animation({ leaf = 'windowsOut',    enabled = true, speed = 1.49, bezier = 'linear', style = 'popin 87%' })
hl.animation({ leaf = 'fadeIn',        enabled = true, speed = 1.73, bezier = 'almostLinear' })
hl.animation({ leaf = 'fadeOut',       enabled = true, speed = 1.46, bezier = 'almostLinear' })
hl.animation({ leaf = 'fade',          enabled = true, speed = 3.03, bezier = 'quick' })
hl.animation({ leaf = 'layers',        enabled = true, speed = 3.81, bezier = 'easeOutQuint' })
hl.animation({ leaf = 'layersIn',      enabled = true, speed = 4,    bezier = 'easeOutQuint', style = 'fade' })
hl.animation({ leaf = 'layersOut',     enabled = true, speed = 1.5,  bezier = 'linear', style = 'fade' })
hl.animation({ leaf = 'fadeLayersIn',  enabled = true, speed = 1.79, bezier = 'almostLinear' })
hl.animation({ leaf = 'fadeLayersOut', enabled = true, speed = 1.39, bezier = 'almostLinear' })
hl.animation({ leaf = 'workspaces',    enabled = true, speed = 1.94, bezier = 'almostLinear', style = 'fade' })
hl.animation({ leaf = 'workspacesIn',  enabled = true, speed = 1.21, bezier = 'almostLinear', style = 'fade' })
hl.animation({ leaf = 'workspacesOut', enabled = true, speed = 1.94, bezier = 'almostLinear', style = 'fade' })
hl.animation({ leaf = 'zoomFactor',    enabled = true, speed = 7,    bezier = 'quick' })

hl.config({
    dwindle = {
        pseudotile = true,
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = 'master',
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
        kb_options = 'caps:escape',
        kb_rules = '',
        repeat_rate = 35,
        repeat_delay = 300,
        follow_mouse = 2,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = 'horizontal',
    action = 'workspace',
})

hl.device({
    name = 'epic-mouse-v1',
    sensitivity = -0.5,
})

-- }}}

-- {{{ binds

hl.bind(mainMod .. ' + Return',    hl.exec_cmd('kitty --directory "$(~/.local/bin/terminal-cwd.sh)"'), { description = 'Open terminal' })
hl.bind(mainMod .. ' + X',         hl.window.kill(),                                      { description = 'Close active window' })
hl.bind(
    mainMod .. ' + M',
    hl.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.exit()'"),
    { description = 'Close hyprland' }
)
hl.bind(mainMod .. ' + E',         hl.exec_cmd('thunar'),                                 { description = 'Open file explorer' })
hl.bind(mainMod .. ' + N',         hl.exec_cmd('nm-connection-editor'),                   { description = 'Open NM Connection Editor' })
hl.bind(mainMod .. ' + SHIFT + N', hl.exec_cmd('kitty --class kitty_nmtui --hold nmtui'), { description = 'Open NM TUI' })
hl.bind(mainMod .. ' + R',         hl.exec_cmd('qalculate-gtk'),                          { description = 'Open Qalculate' })
hl.bind(mainMod .. ' + O',         hl.exec_cmd('kitty --class kitty_status sh -c ~/.local/bin/status_show.sh'), { description = 'Show general status' })
hl.bind(mainMod .. ' + I',         hl.exec_cmd('kitty --class kitty_nmcli nmcli'),        { description = 'Show network status' })
hl.bind(mainMod .. ' + B',         hl.exec_cmd('blueman-manager'),                        { description = 'Open bluetooth manager' })
hl.bind(mainMod .. ' + A',         hl.exec_cmd('hyprpwcenter'),                           { description = 'Open audio manager' })
hl.bind(mainMod .. ' + F',         hl.window.float({ action = 'toggle' }),                { description = 'Toggle floating window' })
hl.bind(mainMod .. ' + SHIFT + F', hl.window.fullscreen(),                                { description = 'Toggle full screen' })
hl.bind(mainMod .. ' + G',         hl.group.toggle(),                                     { description = 'Toggle grouping (tabbed)' })
hl.bind(mainMod .. ' + SHIFT + G', hl.exec_cmd('~/.local/bin/workspace_to_group.sh'),     { description = 'Add all windows to group' })
hl.bind(mainMod .. ' + Tab',       hl.group.next(),                                       { description = 'Change tab in group' })
hl.bind(mainMod .. ' + Space',     hl.exec_cmd(menu),                                     { description = 'Open launcher' })
hl.bind(mainMod .. ' + P',         hl.window.pseudo(),                                    { description = 'Toggle pseudo tiling' })
hl.bind(mainMod .. ' + J',         hl.layout('togglesplit'),                              { description = 'Toggle window splitting' })
hl.bind(mainMod .. ' + H',         hl.exec_cmd('kitty --class kitty_btop --hold btop'),   { description = 'Open btop' })
hl.bind(mainMod .. ' + L',         hl.exec_cmd('hyprlock'),                               { description = 'Lock session' })
hl.bind(mainMod .. ' + SHIFT + L', hl.exec_cmd('~/.local/bin/power_menu.sh'),             { description = 'Open power menu' })
hl.bind(mainMod .. ' + ALT + I',   hl.exec_cmd('~/.local/bin/hypridle_toggle.sh'),        { description = 'Toggle hypridle' })
hl.bind('Print',                   hl.exec_cmd('~/.local/bin/screenshot.sh'),             { description = 'Take screenshot' })
hl.bind('SHIFT + Print',           hl.exec_cmd('~/.local/bin/screenrecord.sh'),           { description = 'Take screen recording' })
hl.bind(mainMod .. ' + SHIFT + P', hl.exec_cmd('~/.local/bin/powerprofilesctl_menu.sh'),  { description = 'Open power mode menu' })
hl.bind(mainMod .. ' + V',         hl.exec_cmd('~/.local/bin/cliphist_show.sh'),          { description = 'Open clipboard history' })
hl.bind(mainMod .. ' + K',         hl.exec_cmd('~/.local/bin/get_binds.sh | hyprlauncher --dmenu'), { description = 'Show keybinds' })

hl.bind(mainMod .. ' + Left',    hl.focus({ direction = 'left' }),  { description = 'Move focus left' })
hl.bind(mainMod .. ' + Right',   hl.focus({ direction = 'right' }), { description = 'Move focus right' })
hl.bind(mainMod .. ' + Up',      hl.focus({ direction = 'up' }),    { description = 'Move focus up' })
hl.bind(mainMod .. ' + Down',    hl.focus({ direction = 'down' }),  { description = 'Move focus down' })
hl.bind(mainMod .. ' + ALT + H', hl.focus({ direction = 'left' }),  { description = 'Move focus left' })
hl.bind(mainMod .. ' + ALT + L', hl.focus({ direction = 'right' }), { description = 'Move focus right' })
hl.bind(mainMod .. ' + ALT + K', hl.focus({ direction = 'up' }),    { description = 'Move focus up' })
hl.bind(mainMod .. ' + ALT + J', hl.focus({ direction = 'down' }),  { description = 'Move focus down' })

hl.bind(mainMod .. ' + SHIFT + Left',  hl.window.move({ direction = 'left' }),  { description = 'Move window left' })
hl.bind(mainMod .. ' + SHIFT + Right', hl.window.move({ direction = 'right' }), { description = 'Move window right' })
hl.bind(mainMod .. ' + SHIFT + Up',    hl.window.move({ direction = 'up' }),    { description = 'Move window up' })
hl.bind(mainMod .. ' + SHIFT + Down',  hl.window.move({ direction = 'down' }),  { description = 'Move window down' })

for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. ' + ' .. key,         hl.workspace(i),                   { description = 'Switch to workspace ' .. i })
    hl.bind(mainMod .. ' + SHIFT + ' .. key, hl.window.move({ workspace = i }), { description = 'Move to workspace ' .. i })
end

hl.bind(mainMod .. ' + Grave', hl.workspace('previous'), { description = 'Switch to previous workspace' })

hl.bind(mainMod .. ' + SHIFT + Period', hl.workspace.move({ monitor = '+1' }), { description = 'Move current workspace to next monitor' })
hl.bind(mainMod .. ' + SHIFT + Comma',  hl.workspace.move({ monitor = '-1' }), { description = 'Move current workspace to previous monitor' })

hl.bind(mainMod .. ' + S',         hl.workspace({ special = 'magic' }),             { description = 'Toggle special workspace' })
hl.bind(mainMod .. ' + SHIFT + S', hl.window.move({ workspace = 'special:magic' }), { description = 'Move to magic workspace' })

hl.bind(mainMod .. ' + mouse_down',hl.workspace('e+1'), { description = 'Scroll workspaces' })
hl.bind(mainMod .. ' + mouse_up',  hl.workspace('e-1'), { description = 'Scroll workspaces' })

hl.bind(mainMod .. ' + mouse:272', hl.window.drag(),   { mouse = true, description = 'Move with mouse' })
hl.bind(mainMod .. ' + mouse:273', hl.window.resize(), { mouse = true, description = 'Resize with mouse' })

hl.bind('XF86AudioRaiseVolume',  hl.exec_cmd('swayosd-client --output-volume raise'),       { locked = true, repeating = true, description = 'Volume raise' })
hl.bind('XF86AudioLowerVolume',  hl.exec_cmd('swayosd-client --output-volume lower'),       { locked = true, repeating = true, description = 'Volume lower' })
hl.bind('XF86AudioMute',         hl.exec_cmd('swayosd-client --output-volume mute-toggle'), { locked = true, repeating = true, description = 'Output mute toggle' })
hl.bind('XF86AudioMicMute',      hl.exec_cmd('swayosd-client --input-volume mute-toggle'),  { locked = true, repeating = true, description = 'Input mute toggle' })
hl.bind('XF86MonBrightnessUp',   hl.exec_cmd('swayosd-client --brightness raise'),          { locked = true, repeating = true, description = 'Brightness raise' })
hl.bind('XF86MonBrightnessDown', hl.exec_cmd('swayosd-client --brightness lower'),          { locked = true, repeating = true, description = 'Brightness lower' })

hl.bind('XF86AudioNext',  hl.exec_cmd('playerctl next'),       { locked = true, description = 'Play next' })
hl.bind('XF86AudioPause', hl.exec_cmd('playerctl play-pause'), { locked = true, description = 'Pause' })
hl.bind('XF86AudioPlay',  hl.exec_cmd('playerctl play-pause'), { locked = true, description = 'Play' })
hl.bind('XF86AudioPrev',  hl.exec_cmd('playerctl previous'),   { locked = true, description = 'Play prev' })

hl.bind('SUPER + Equal', hl.window.resize({ x = 40, y = 40, relative = true }),   { description = 'Stretch active window' })
hl.bind('SUPER + Minus', hl.window.resize({ x = -40, y = -40, relative = true }), { description = 'Contract active window' })

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
    name = 'kitty-nmtui',
    match = { class = 'kitty_nmtui' },
    float = true,
    center = true,
    size = 'monitor_w*0.5 monitor_h*0.5',
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
    name = 'kitty-powerprofilesctl',
    match = { class = 'kitty_powerprofilesctl' },
    float = true,
    center = true,
    size = '400 100',
})
hl.window_rule({
    name = 'kitty-cliphist-fzf',
    match = { class = 'kitty_cliphist_fzf' },
    float = true,
    center = true,
    size = 'monitor_w*0.6 monitor_h*0.6',
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
