# klipper_on_unidle

This Klippy Extra adds Support for an `ON_UNIDLE` configuration section that
can run gcode when the printer transitions from the `Idle` state to `Ready.`

While we could fake this with `delayed_gcode` macros, it would rely on polling
instead of counting on an event notification system, which is what we'll do
here.

The `idle_timeout` module already tracks states Idle, Ready, and Printing, as
well as handles the time duration that must pass before we regard the system as
`Idle`, but it only acts upon transition into `Idle`. In this module, we're
only interested in acting on the transition out of `Idle` or at startup
(represented by `klippy:ready`).

Thus, `on_unidle` works by monitoring the transition to the first
`idle_timeout:ready` following `klippy:ready` or `idle_timeout:idle`. Note that
there's no point in reacting to `idle_timeout:printing`, because any gcode is
added to the end of the current queue, and would execute at the same time as
`idle_timeout:ready` does anyway.

Additionally, if you have a display with a menu – typically using a rotary
encoder – and the printer state is `Idle`, then using the menu will bring your
printer out of `Idle` state as well.


## Install

```
cd ~
git clone https://github.com/balthisar/klipper_on_unidle.git
cd klipper_on_unidle
./install.sh
```

## Uninstall

```
cd ~/klipper_on_unidle
./install.sh -u
```

## Important Patch Note

Until and unless PR [#6897](https://github.com/Klipper3d/klipper/pull/6897) is
merged, some very small event-related code must be patched into klipper, _only
if you want to use the display knob to wakeup feature._ These two lines…

```
self.printer.send_event('menu:%s' % (key), key, eventtime) # granular
self.printer.send_event('menu:action', key, eventtime) # any item
```

…have to be added into klippy's `menu.py` file. The installer will do this
automatically for you after warning that it will happen. The patch is applied
from the file `menu.py.patch` in this repository.

Klipper updates may overwrite this file, in which case you'll have to either
run the install again, or apply the patch manually:

```
patch ~/klipper/klippy/extras/display/menu.py ~/klipper_on_unidle/menu.py.patch
```


## Configuration

### [on_unidle]

Configuration of the ON_UNIDLE Klippy extra.

```
[on_unidle]
#gcode:
#   A list of G-Code commands to execute when leaving the idle state. See
#   docs/Command_Templates.md for G-Code format. This setting is required.
#   It's not really recommended to have long running gcode or cause motor
#   movement here.
#echo_events: False
#   If set to True, Idle state changes will echo to the gcode console. This
#   could be useful for troubleshooting events, and so see how this module
#   works.
#display_unidle: True
#   By default, this module will detect the use of your display and un-idle the
#   printer up as a result. For example if your printer turns off its case
#   lights at Idle, and configured to turn on its case lights on unidle, then
#   turning the display's knob is a quick and effective means. However if you
#   prefer Klippy's default behavior, change this setting to `False`.
```
