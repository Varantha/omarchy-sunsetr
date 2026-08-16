import QtQuick
import Quickshell.Io
import "SunsetrModel.js" as Model

// Owns the sunsetr night light state for the bar widget and the CLI.
//
// sunsetr has no event stream, so this polls `sunsetr status` on a timer and
// re-probes shortly after every action. Actions are sunsetr presets:
//   default            -> automatic geo/time schedule
//   <dayPreset>        -> static day temperature (force off)
//   <nightPreset>      -> static night temperature (force on)
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  // Overridable by the bar widget from its shell.json settings.
  property string dayPreset: "day"
  property string nightPreset: "night"
  property int pollInterval: 30

  property bool stateLoaded: false
  property bool running: false
  property var status: ({ running: false })
  property var temperature: null
  property var gamma: null
  property string preset: "default"
  property string period: ""
  property string nextPeriod: ""
  property string lastError: ""
  property bool busy: applyProcess.running || startProcess.running

  readonly property bool enabled: stateLoaded && Model.isNightlight(temperature)
  readonly property bool forced: preset !== "" && preset !== "default"
  readonly property string summary: Model.describe(status, dayPreset, nightPreset)

  function refresh() {
    if (!statusProbe.running) statusProbe.running = true
  }

  function refreshSoon() {
    refreshTimer.restart()
  }

  // Run `sunsetr preset <name>` (start the daemon first if it is not up).
  function applyPreset(name) {
    var target = String(name || "default")
    if (applyProcess.running) {
      pendingPreset = target
      hasPendingPreset = true
      return
    }
    runApply(target)
  }

  property bool hasPendingPreset: false
  property string pendingPreset: ""

  function runApply(target) {
    lastError = ""
    applyProcess.command = ["bash", "-c",
      // sunsetr's own --background uses the old `hyprctl dispatch exec` syntax
      // and fails on Hyprland >= 0.56, so launch it the way omarchy does.
      "if ! pgrep -x sunsetr >/dev/null; then setsid uwsm-app -- sunsetr >/dev/null 2>&1 & sleep 1.5; fi; " +
      "exec sunsetr preset \"$0\"", target]
    applyProcess.running = true
  }

  function setNightlight(value) {
    applyPreset(value ? nightPreset : dayPreset)
  }

  function auto() { applyPreset("default") }

  function toggle() {
    var target = Model.toggleTarget(status, dayPreset, nightPreset)
    applyPreset(target)
    return target
  }

  function start() {
    if (startProcess.running) return
    lastError = ""
    startProcess.running = true
  }

  function stop() {
    applyProcess.command = ["sunsetr", "stop"]
    applyProcess.running = true
  }

  function applyStatus(text) {
    var parsed = Model.parseStatus(text)
    status = parsed
    running = parsed.running
    temperature = parsed.temperature
    gamma = parsed.gamma
    preset = parsed.preset ? String(parsed.preset) : "default"
    period = parsed.period ? String(parsed.period) : ""
    nextPeriod = parsed.nextPeriod ? String(parsed.nextPeriod) : ""
    stateLoaded = true
  }

  Process {
    id: statusProbe
    command: ["sunsetr", "status"]
    stdout: StdioCollector {
      id: statusOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: statusErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      // Both streams are needed: the "not running" notice goes to stderr.
      root.applyStatus(String(statusOut.text || "") + "\n" + String(statusErr.text || ""))
    }
  }

  Process {
    id: applyProcess
    // sunsetr prints its boxed error report on stdout, so collect both.
    stdout: StdioCollector {
      id: applyOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: applyErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var raw = String(applyOut.text || "") + "\n" + String(applyErr.text || "")
        var err = Model.stripAnsi(raw).replace(/[┏┣┃┗╹━╸]/g, "").trim()
        var lines = err.split("\n").map(function(l) { return l.trim() }).filter(function(l) { return l !== "" && !/^sunsetr v/.test(l) })
        var idx = -1
        for (var i = 0; i < lines.length; i++) if (/^\[ERROR\]/.test(lines[i])) { idx = i; break }
        var pick = idx >= 0 ? lines[idx] : (lines.length ? lines[0] : "")
        // sunsetr wraps details onto the next line ("... not found at:\n  ~/path").
        if (idx >= 0 && /[:]$/.test(pick) && idx + 1 < lines.length) pick += " " + lines[idx + 1]
        root.lastError = pick ? pick.replace(/^\[ERROR\]\s*/, "") : ("sunsetr exited " + exitCode)
        console.warn("varantha.sunsetr:", root.lastError)
      }
      if (root.hasPendingPreset) {
        root.hasPendingPreset = false
        root.runApply(root.pendingPreset)
        return
      }
      root.refreshSoon()
    }
  }

  Process {
    id: startProcess
    command: ["bash", "-c", "pgrep -x sunsetr >/dev/null || { setsid uwsm-app -- sunsetr >/dev/null 2>&1 & sleep 1.5; }"]
    onExited: root.refreshSoon()
  }

  // Sunsetr's smoothing (startup_duration, default 0.5s) means the status
  // right after a preset switch can still show the old temperature.
  Timer {
    id: refreshTimer
    interval: 1200
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: Math.max(5, root.pollInterval) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  IpcHandler {
    target: "sunsetr"

    function status(): string {
      return JSON.stringify({
        running: root.running,
        enabled: root.enabled,
        temperature: root.temperature,
        gamma: root.gamma,
        preset: root.preset,
        forced: root.forced,
        period: root.period,
        nextPeriod: root.nextPeriod,
        error: root.lastError
      })
    }

    function refresh(): void { root.refresh() }

    function toggle(): string { return root.toggle() }
    function enable(): string { root.setNightlight(true); return root.nightPreset }
    function disable(): string { root.setNightlight(false); return root.dayPreset }
    function auto(): string { root.auto(); return "default" }
    function preset(name: string): string { root.applyPreset(name); return String(name) }
    function start(): void { root.start() }
    function stop(): void { root.stop() }
  }
}
