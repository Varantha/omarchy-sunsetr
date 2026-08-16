// Run: node tests/model.test.js
const assert = require("node:assert/strict")
const M = require("../SunsetrModel.js")

const RUNNING = ` Active preset: default
Current period: Day 󰖨 
         State: stable
   Temperature: 6500K
         Gamma: 100.0%
   Next period: 19:20:12 (in 2h11m)
`
const NIGHT = ` Active preset: default
Current period: Night 󰖔
         State: stable
   Temperature: 3300K
         Gamma: 90.0%
   Next period: 05:41:03 (in 9h)
`
const FORCED = ` Active preset: day
Current period: Day
         State: stable
   Temperature: 6500K
         Gamma: 100.0%
`
const DOWN = "[\x1b[31mERROR\x1b[0m] No sunsetr process is running\n  Start sunsetr first or use 'sunsetr --debug' to run\n"

let s = M.parseStatus(RUNNING)
assert.equal(s.running, true)
assert.equal(s.preset, "default")
assert.equal(s.period, "Day")
assert.equal(s.temperature, 6500)
assert.equal(s.gamma, 100)
assert.equal(s.nextPeriod, "19:20:12 (in 2h11m)")
assert.equal(M.isNightlight(s.temperature), false)
assert.equal(M.toggleTarget(s, "day", "night"), "night")
assert.equal(M.describe(s), "Night Light off · 6500K · next: 19:20:12 (in 2h11m)")

s = M.parseStatus(NIGHT)
assert.equal(s.period, "Night")
assert.equal(M.isNightlight(s.temperature), true)
assert.equal(M.toggleTarget(s, "day", "night"), "day")

s = M.parseStatus(FORCED)
assert.equal(s.preset, "day")
assert.equal(M.toggleTarget(s, "day", "night"), "default")
assert.equal(M.describe(s), "Night Light off · 6500K · forced: day")

s = M.parseStatus(DOWN)
assert.equal(s.running, false)
assert.equal(s.temperature, null)
assert.equal(M.toggleTarget(s, "day", "night"), "night")
assert.equal(M.describe(s), "sunsetr not running")

s = M.parseStatus("")
assert.equal(s.running, false)

console.log("ok")
