# -*- coding: utf-8 -*-
# Copyright (c) 2010 Aldo Cortesi
# Copyright (c) 2010, 2014 dequis
# Copyright (c) 2012 Randall Ma
# Copyright (c) 2012-2014 Tycho Andersen
# Copyright (c) 2012 Craig Barnes
# Copyright (c) 2013 horsik
# Copyright (c) 2013 Tao Sauvage
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from typing import List  # noqa: F401

from libqtile import bar, layout, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

import subprocess
import psutil
import requests

mod = "mod4"
terminal = "alacritty -e fish"
lock = "slock"
rofi = "rofi -show  -modi ':~/.config/rofi/rofi.sh'"
location = "Madrid"

def get_backlight():
    return (
        ""
        + subprocess.check_output("xbacklight -get", shell=True).decode().strip().split('.')[0]
        + "% "
    )

def get_cpu():
    return (
        " "
        + str(int(psutil.cpu_percent(interval=5)))
        #+ "%  <span foreground='red'>text</span>"
        + "% "
    )

def get_mem():
    mem = psutil.virtual_memory()
    return "{:.0%} ".format(1-(mem.available/mem.total))

def get_disk():
    return "{}% ".format(str(int(psutil.disk_usage('/').percent)))

def get_weather():
    res = requests.get("http://wttr.in/{}?format=%C,%f ".format(location))
    text, temp = res.text.replace('+','').split(',')
    if "Clear" in text:
        return "{}".format(temp)
    return text

keys = [
    # Common
    Key([mod], "l", lazy.spawn(lock)),
    Key([mod], 'r', lazy.spawn(rofi)),
    Key([mod], "Return", lazy.spawn(terminal)), 

    # Windows ops
    Key([mod], "w", lazy.window.kill(), desc="Kill window"), 
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="toggle fullscreen"),
    Key([mod, "shift"], "f", lazy.window.toggle_floating(), desc="Float window"),

    # Layout
    Key([mod], "Left", lazy.layout.left()),
    Key([mod], "Right", lazy.layout.right()),
    Key([mod], "Down", lazy.layout.down()),
    Key([mod], "Up", lazy.layout.up()),
    Key([mod, "shift"], "Left", lazy.layout.swap_left()),
    Key([mod, "shift"], "Right", lazy.layout.swap_right()),
    Key([mod, "shift"], "Down", lazy.layout.shuffle_down()),
    Key([mod, "shift"], "Up", lazy.layout.shuffle_up()),
    Key([mod], "g", lazy.layout.grow()),
    Key([mod], "s", lazy.layout.shrink()),
    Key([mod], "n", lazy.layout.normalize()),
    Key([mod], "m", lazy.layout.maximize()),
    #Key([mod], "space", lazy.layout.flip()),    

    # Qtile ops
    Key([mod, "shift"], "r", lazy.restart(), desc="Restart Qtile"),
    Key([mod, "shift"], "q", lazy.shutdown(), desc="Quit Qtile"),
    Key([mod], "Tab", lazy.next_layout(), desc="Next Layout"),

    #Specials
    Key([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +10%")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 10%-")),
]

old_keys = [
    # Switch between windows
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.next(),
        desc="Move window focus to other window"),

    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(),
        desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(),
        desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(),
        desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),

    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "h", lazy.layout.grow_left(),
        desc="Grow window to the left"),
    Key([mod, "control"], "l", lazy.layout.grow_right(),
        desc="Grow window to the right"),
    Key([mod, "control"], "j", lazy.layout.grow_down(),
        desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),

    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes
    Key([mod, "shift"], "Return", lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack"),
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),

    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod], "w", lazy.window.kill(), desc="Kill focused window"),

    Key([mod, "control"], "r", lazy.restart(), desc="Restart Qtile"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod], "r", lazy.spawncmd(),
        desc="Spawn a command using a prompt widget"),
]


group_names = ["WORK","HOME","COMMS","IDLE"]
groups = [Group(name) for name in group_names]
for i, name in enumerate(group_names,1):
    keys.extend([
        Key([mod], str(i), lazy.group[name].toscreen()),
        #Key([mod, "shift"], str(i), lazy.window.togroup(name, switch_group=True))
        Key([mod, "shift"], str(i), lazy.window.togroup(name))
    ])

layout_theme = {"border_width": 3,
                "margin": 6,
                #"border_focus": "#0abdc6",
                "border_focus": "#c80c9a",
                #"border_normal": "#1D2330"
                "border_normal": "#271ea0"
                }

layouts = [
    layout.MonadTall(**layout_theme),    
    # layout.Columns(**layout_theme),
    # layout.Max(**layout_theme),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2,**layout_theme),
    # layout.Bsp(**layout_theme),
    # layout.Matrix(**layout_theme),
    layout.MonadWide(**layout_theme),
    # layout.RatioTile(**layout_theme),
    # layout.Tile(**layout_theme),
    # layout.TreeTab(**layout_theme),
    # layout.VerticalTile(**layout_theme),
    layout.Zoomy(**layout_theme),
    # layout.Floating(**layout_theme),
]

widget_defaults = dict(
    font='Iosevka',
    fontsize=18,
    padding=3
)
extension_defaults = widget_defaults.copy()

screens = [
    Screen(
        top=bar.Bar(
            [
                widget.TextBox(" "),
                widget.GroupBox(
                       font = "Iosevka",
                       margin_y = 3,
                       margin_x = 5,
                       padding_y = 2,
                       padding_x = 3,
                       borderwidth = 3,
                       active = "#FFFFFF",
                       inactive = "#FFFFFF",
                       rounded = True,
                       highlight_color = "#080c9a",
                       highlight_method = "block",
                       # this_current_screen_border = "#0abdc6",
                       this_current_screen_border = "#c80c9a",
                       # this_current_screen_border = "#612f91",
                       this_screen_border = "#c80c9a",
                       # other_current_screen_border = colors[6],
                       # other_screen_border = colors[4],
                       # foreground = colors[2],
                       # background = colors[0]
                       ),
                widget.Sep(linewidth = 3, padding = 10, foreground = "#c80c9a"),
                widget.TextBox(" "),
                # widget.Spacer(), 
                # widget.Prompt(),
                widget.WindowName(),
                widget.TextBox(" "),
                widget.Notify(),
                widget.Sep(linewidth = 3, padding = 10, foreground = "#c80c9a"),
                widget.GenPollText(func=get_cpu,update_interval=1),
                widget.GenPollText(func=get_mem,update_interval=10),
                widget.GenPollText(func=get_disk,update_interval=5),
                widget.GenPollText(func=get_backlight,update_interval=5),
                widget.GenPollText(func=get_weather,update_interval=5),
                widget.Wlan(format="{percent:2.0%} "),
                widget.Battery(discharge_char="",charge_char="",format="{char}{percent:2.0%} ",update_interval=5),
                widget.Clock(format='%H:%M'),
                widget.Systray(),
                widget.TextBox(" "),
            ],
            size=32,
            margin=(6,7,0,7),
            opacity=0.9,
            background="#000b1e"
        ),
    ),
]

# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
         start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front())
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: List
main = None  # WARNING: this is deprecated and will be removed soon
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
floating_layout = layout.Floating(**layout_theme,float_rules=[
    # Run the utility of `xprop` to see the wm class and name of an X client.
    *layout.Floating.default_float_rules,
    Match(wm_class='confirmreset'),  # gitk
    Match(wm_class='makebranch'),  # gitk
    Match(wm_class='maketag'),  # gitk
    Match(wm_class='ssh-askpass'),  # ssh-askpass
    Match(title='branchdialog'),  # gitk
    Match(title='rofi'),
    Match(title='pinentry'),  # GPG key password entry
])
auto_fullscreen = True
focus_on_window_activation = "smart"


# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "CDE"
