# omarchy-sunsetr

Omarchy shell plugin (`sam.sunsetr`) that replaces the built-in
`omarchy.nightlight` service with one backed by [sunsetr](https://github.com/psi4j/sunsetr)
instead of hyprsunset.

The stock night light plugin polls `hyprctl hyprsunset temperature` and spawns
`hyprsunset` on click. If sunsetr owns the CTM (colour temperature) protocol,
the stock icon is permanently dead and clicking it starts a second controller
that fights sunsetr. This plugin:

- shows sunsetr's real state in the bar (dim = off, bright = night light on)
- toggles by switching sunsetr presets: `default` (auto schedule) ⇄ forced `day` / `night`
- disables `omarchy.nightlight` when enabled (via `clonedFrom`, so `omarchy plugin disable sam.sunsetr` restores the stock one)
- ships a shell-aware CLI (`sunsetr-nightlight`) for keybindings and the menu

## Layout

```
manifest.json      service + bar-widget, clonedFrom omarchy.nightlight
Service.qml        polls `sunsetr status`, applies presets, IPC target `sunsetr`
BarWidget.qml      bar icon + popup (Auto / Day / Night)
SunsetrModel.js    pure parsing/decision helpers (node-testable)
bin/setup          idempotent installer for this machine
bin/sunsetr-nightlight   CLI: toggle|on|off|auto|status|start|stop|refresh
presets/           day / night sunsetr preset templates
extensions/        menu override snippet
tests/             `node tests/model.test.js`
```

## Install

```bash
git clone <this repo> ~/Work/omarchy-sunsetr
~/Work/omarchy-sunsetr/bin/setup
```

`bin/setup` will:

1. create `~/.config/sunsetr/presets/{day,night}/sunsetr.toml` if missing,
   with values from your live `sunsetr get day_temp day_gamma night_temp night_gamma`
2. link `bin/sunsetr-nightlight` into `~/.local/bin`
3. symlink the checkout to `~/.config/omarchy/plugins/sam.sunsetr`
4. remove `NightLight` from `omarchy.indicators` in `~/.config/omarchy/shell.json` (backup kept)
5. add a `trigger.toggle.nightlight` override to `~/.config/omarchy/extensions/omarchy-menu.jsonc`
6. `omarchy plugin enable sam.sunsetr --before omarchy.indicators`

Then rebind the key yourself in `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("SUPER + CTRL + N")
o.bind("SUPER + CTRL + N", "Toggle nightlight", "sunsetr-nightlight toggle")
```

Alternatively `omarchy plugin add <git-url> --enable`, then run `bin/setup --no-enable`
from the installed copy for steps 1–5.

## Behaviour

| Action | Result |
|---|---|
| left click / `toggle` | forced preset → `default`; auto+on → `day`; auto+off → `night` |
| right click | popup: period, temperature, gamma, preset, next period; Auto/Day/Night chips |
| middle click | refresh |
| `enable` / `disable` / `auto` (IPC) | `sunsetr preset night` / `day` / `default` |

"On" means temperature < 6000K, same threshold as the stock plugin. State is
polled every `interval` seconds (default 30) plus ~1.2s after each action.

If sunsetr is not running, any action starts it with `uwsm-app -- sunsetr`
(sunsetr's own `--background` uses the pre-0.56 `hyprctl dispatch exec` syntax
and fails on current Hyprland).

## Widget settings (shell.json)

```json
{ "id": "sam.sunsetr", "interval": 30, "dayPreset": "day", "nightPreset": "night", "hideInactive": false }
```

`hideInactive: true` collapses the icon to zero width while night light is off.

## IPC

```
omarchy-shell sunsetr status|refresh|toggle|enable|disable|auto|start|stop
omarchy-shell sunsetr preset <name>
omarchy-shell sam.sunsetr refresh|toggle|open|close   # bar widget
```

## Uninstall

```bash
omarchy plugin disable sam.sunsetr    # re-enables omarchy.nightlight
rm ~/.config/omarchy/plugins/sam.sunsetr ~/.local/bin/sunsetr-nightlight
```
Restore `NightLight` in `omarchy.indicators` items and drop the menu override by hand.
