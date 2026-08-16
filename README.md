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
- hides the stock `NightLight` bar icon; the stock `omarchy.nightlight` *service* is left dormant (harmless: one failed `hyprctl` probe), so `disabledPlugins` only ever reflects your own choices
- `bin/setup --uninstall` puts everything back from a pre-install snapshot
- ships a shell-aware CLI (`sunsetr-nightlight`) for keybindings and the menu

## Layout

```
manifest.json      service + bar-widget
Service.qml        polls `sunsetr status`, applies presets, IPC target `sunsetr`
BarWidget.qml      bar icon + popup (Auto / Day / Night)
SunsetrModel.js    pure parsing/decision helpers (node-testable)
bin/setup          idempotent installer / --uninstall for this machine
bin/sunsetr-nightlight   CLI: toggle|on|off|auto|status|start|stop|refresh
presets/           day / night sunsetr preset templates
extensions/        menu override snippet
tests/             `node tests/model.test.js`
```

## Install

```bash
git clone <this repo> ~/.config/omarchy/plugins/sam.sunsetr
~/.config/omarchy/plugins/sam.sunsetr/bin/setup
```

The checkout has to *be* the plugin directory (not a symlink to it): the
shell hot-reloads via `inotifywait -r`, which does not follow symlinks. Keep a
symlink elsewhere for editing if you like (`ln -s ~/.config/omarchy/plugins/sam.sunsetr ~/Work/omarchy-sunsetr`).

`bin/setup` will:

0. snapshot pre-install state to `~/.local/state/omarchy-sunsetr/state.json`
   (first run only; re-runs keep the original snapshot)
1. create `~/.config/sunsetr/presets/{day,night}/sunsetr.toml` if missing,
   with values from your live `sunsetr get day_temp day_gamma night_temp night_gamma`
2. copy the checkout to `~/.config/omarchy/plugins/sam.sunsetr` if it lives elsewhere
3. link `bin/sunsetr-nightlight` into `~/.local/bin`
4. remove `NightLight` from `omarchy.indicators` in `~/.config/omarchy/shell.json` (backup kept)
5. add a `trigger.toggle.nightlight` override to `~/.config/omarchy/extensions/omarchy-menu.jsonc`
6. `omarchy plugin enable sam.sunsetr --before omarchy.indicators`

The stock `omarchy.nightlight` service is not disabled. It idles (its
`hyprctl hyprsunset` probe fails once, then nothing) and its IPC target
(`nightlight`) does not clash with ours (`sunsetr`). Nothing in the bar or menu
reaches it any more, only `omarchy toggle nightlight` — avoid that.

Then rebind the key yourself in `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("SUPER + CTRL + N")
o.bind("SUPER + CTRL + N", "Toggle nightlight", "sunsetr-nightlight toggle")
```

Alternatively `omarchy plugin add <git-url> --enable`, then run `bin/setup --no-enable`
from the installed copy for steps 1–5.

### Developing

Edits under `~/.config/omarchy/plugins/sam.sunsetr/` trigger a plugin reload,
but in practice both the service and the widget kept running the old code
until `omarchy restart shell` — restart after every QML edit.
`omarchy-shell sam.sunsetr debug` dumps the widget's visibility state.
`node tests/model.test.js` covers the parser/decision logic without the shell.

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
{ "id": "sam.sunsetr", "interval": 30, "dayPreset": "day", "nightPreset": "night", "reveal": "hover" }
```

`reveal` controls the icon while night light is off: `hover` (default) hides
it and peeks it at 45% when the bar's centre section is hovered — the same
gesture the stock indicators use; `always` keeps it visible dimmed; `never`
keeps it collapsed.

## IPC

```
omarchy-shell sunsetr status|refresh|toggle|enable|disable|auto|start|stop
omarchy-shell sunsetr preset <name>
omarchy-shell sam.sunsetr refresh|toggle|open|close|debug   # bar widget
```

## Uninstall

```bash
~/.config/omarchy/plugins/sam.sunsetr/bin/setup --uninstall
omarchy plugin remove sam.sunsetr
```

`--uninstall` disables the plugin, unlinks the CLI, and restores from the
snapshot: `omarchy.indicators` items exactly as they were, our menu override
removed (left alone if it pre-existed or was edited), presets we created
removed if unmodified, sunsetr back on `default`.

Rules of restraint:

- The stock `NightLight` icon is only put back if `omarchy.nightlight` is
  still enabled. If you disabled it — before or while this plugin was
  installed — it stays disabled and iconless. We never re-enable it.
- If the bar layout was rearranged since install and the snapshot no longer
  lines up, `NightLight` is appended to whatever `items` an indicators
  widget has now (never invents an `items` list for one relying on defaults).
- Keybinding changes are yours; the script prints a reminder.

If you already ran `omarchy plugin remove` first, re-clone anywhere and run
`bin/setup --uninstall` from there — the snapshot lives outside the plugin dir.
