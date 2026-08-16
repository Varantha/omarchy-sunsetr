// Pure helpers shared by Service.qml and the CLI-side tests. Keep this free of
// Qt imports so it can also run under node for `bin/test`.

// Temperatures below this count as "night light on". Same threshold the
// built-in omarchy.nightlight service uses, so `enabled` means the same thing.
var IDENTITY_TEMPERATURE = 6000

// `sunsetr status` prints aligned "Label: value" lines, e.g.
//    Active preset: default
//   Current period: Day 󰖨
//            State: stable
//      Temperature: 6500K
//            Gamma: 100.0%
//      Next period: 19:20:12 (in 2h11m)
// When the daemon is down it prints an ANSI-coloured
//   [ERROR] No sunsetr process is running
// and still exits 0, so "running" has to come from the parse, not the rc.
function parseStatus(output) {
  var text = stripAnsi(String(output === undefined || output === null ? "" : output))
  var result = {
    running: false,
    preset: null,
    period: null,
    state: null,
    temperature: null,
    gamma: null,
    nextPeriod: null,
    raw: text.trim()
  }
  if (/No sunsetr process is running/i.test(text)) return result

  var lines = text.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([A-Za-z][A-Za-z ]*?)\s*:\s*(.*?)\s*$/)
    if (!m) continue
    var key = m[1].toLowerCase()
    var value = m[2]
    if (key === "active preset") result.preset = value
    else if (key === "current period") result.period = value.replace(/[^\x20-\x7E]+\s*$/, "").trim()
    else if (key === "state") result.state = value
    else if (key === "temperature") result.temperature = firstNumber(value)
    else if (key === "gamma") result.gamma = firstNumber(value)
    else if (key === "next period") result.nextPeriod = value
  }
  result.running = result.temperature !== null || result.preset !== null
  return result
}

function firstNumber(value) {
  var m = String(value).match(/-?[0-9]+(?:\.[0-9]+)?/)
  return m ? Number(m[0]) : null
}

function stripAnsi(text) {
  return String(text).replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")
}

function isNightlight(temperature) {
  return temperature !== null && temperature !== undefined && temperature < IDENTITY_TEMPERATURE
}

// Which sunsetr command a toggle should run, given the current state.
//   forced (any non-default preset)  -> back to the automatic schedule
//   auto + night light on            -> force day
//   auto + night light off           -> force night
function toggleTarget(status, dayPreset, nightPreset) {
  var preset = status && status.preset ? String(status.preset) : "default"
  if (preset !== "default") return "default"
  return isNightlight(status ? status.temperature : null) ? dayPreset : nightPreset
}

// Human summary for tooltips.
function describe(status, dayPreset, nightPreset) {
  if (!status || !status.running) return "sunsetr not running"
  var parts = []
  var on = isNightlight(status.temperature)
  parts.push(on ? "Night Light on" : "Night Light off")
  if (status.temperature !== null) parts.push(status.temperature + "K")
  if (status.preset && status.preset !== "default") parts.push("forced: " + status.preset)
  else if (status.nextPeriod) parts.push("next: " + status.nextPeriod)
  return parts.join(" · ")
}

if (typeof module !== "undefined") {
  module.exports = {
    IDENTITY_TEMPERATURE: IDENTITY_TEMPERATURE,
    parseStatus: parseStatus,
    stripAnsi: stripAnsi,
    isNightlight: isNightlight,
    toggleTarget: toggleTarget,
    describe: describe
  }
}
