# omarchy-sunsetr

Night light for [Omarchy](https://omarchy.org) driven by [sunsetr](https://github.com/psi4j/sunsetr) instead of hyprsunset.

Omarchy's built-in night light (`omarchy.nightlight`) talks to hyprsunset only. If you run sunsetr, the stock bar icon is permanently dead and clicking it spawns hyprsunset on top of sunsetr. This plugin replaces the icon, keybind target and menu entry with ones that drive sunsetr presets.

## What you get

- Bar icon `󰔎`: hidden while off, peeks on centre-section hover (like the stock indicators), lit while on.
  Left = toggle · right = status popup with Auto / Day / Night · middle = refresh.
- Toggle logic: forced preset → back to auto; auto + on → force day; auto + off → force night.
- `sunsetr-nightlight` CLI for keybindings and scripts.
- Menu Trigger ▸ Toggle ▸ Nightlight repointed at sunsetr, ✓ when on.
- Starts sunsetr if it isn't running.
- Clean uninstall from a pre-install snapshot.

## Requirements

- Omarchy with the Quickshell shell (`omarchy-shell`), Hyprland.
- `sunsetr` installed, configured (`sunsetr geo`), and autostarted, e.g. in `~/.config/hypr/autostart.lua`:
  ```lua
  o.launch_on_start("sunsetr")
  ```
  Do not autostart hyprsunset.

## Install

```bash
git clone https://github.com/Varantha/omarchy-sunsetr.git ~/.config/omarchy/plugins/sam.sunsetr
~/.config/omarchy/plugins/sam.sunsetr/bin/setup
```

`bin/setup` (idempotent) will:

1. snapshot pre-install state to `~/.local/state/omarchy-sunsetr/state.json`
2. create `~/.config/sunsetr/presets/{day,night}/sunsetr.toml` if missing (static mode, values from your `sunsetr.toml`)
3. link `sunsetr-nightlight` into `~/.local/bin`
4. remove `NightLight` from `omarchy.indicators` in `~/.config/omarchy/shell.json`
5. override `trigger.toggle.nightlight` in `~/.config/omarchy/extensions/omarchy-menu.jsonc`
6. `omarchy plugin enable sam.sunsetr --before omarchy.indicators`

Then rebind the key yourself in `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("SUPER + CTRL + N")
o.bind("SUPER + CTRL + N", "Toggle nightlight", "sunsetr-nightlight toggle")
```

If the icon doesn't show up, `omarchy restart shell`.

The stock `omarchy.nightlight` service is left enabled but dormant (its hyprsunset probe fails once, then it idles). Nothing in the bar or menu reaches it any more. `omarchy toggle nightlight` still does — avoid it.

## Configure

Widget entry in `shell.json` (`bar.layout.center`):

```json
{ "id": "sam.sunsetr", "interval": 30, "dayPreset": "day", "nightPreset": "night", "reveal": "hover" }
```

| key | default | meaning |
|---|---|---|
| `interval` | `30` | seconds between `sunsetr status` polls |
| `dayPreset` | `"day"` | sunsetr preset used to force off |
| `nightPreset` | `"night"` | sunsetr preset used to force on |
| `reveal` | `"hover"` | while off: `hover` (peek with centre section), `always` (dimmed), `never` |

**Presets.** `default` is sunsetr's built-in "no preset" state — nothing to create. `day` and `night` are just names: bring your own preset files, or point `dayPreset`/`nightPreset` at ones you already have. Existing preset files are never overwritten. "On" means the current temperature is below 6000 K (same threshold as stock), whatever the preset contains.

## Use

```
sunsetr-nightlight toggle|on|off|auto|status|start|stop|refresh
omarchy-shell sunsetr status|toggle|enable|disable|auto|preset <name>|start|stop|refresh
```

The CLI goes through the shell when it is running (icon updates instantly) and falls back to `sunsetr` directly otherwise. Set `SUNSETR_DAY_PRESET` / `SUNSETR_NIGHT_PRESET` for the fallback path if you renamed the presets.

## Uninstall

```bash
~/.config/omarchy/plugins/sam.sunsetr/bin/setup --uninstall
omarchy plugin remove sam.sunsetr
```

Restores `omarchy.indicators`, removes our menu override and CLI link, deletes presets we created (if unmodified), returns sunsetr to `default`. The stock `NightLight` icon is only put back if you never disabled `omarchy.nightlight` yourself. Keybindings are yours to revert. Snapshot lives outside the plugin dir, so this works even after `omarchy plugin remove` (re-clone anywhere and run it).

## Notes

- sunsetr's `--background` uses the pre-0.56 `hyprctl dispatch exec` syntax and fails on current Hyprland; the plugin starts sunsetr with `uwsm-app` instead.
- While a forced preset is active, sunsetr's schedule is paused until you go back to Auto — that's sunsetr's preset semantics.
- Developing: after editing QML, `omarchy restart shell` (hot reload leaves the old instances running). `node tests/model.test.js` covers the parser/decision logic. `omarchy-shell sam.sunsetr debug` dumps widget state.

## License

MIT
