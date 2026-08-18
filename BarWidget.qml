import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Night light bar icon driven by the varantha.sunsetr service.
//   left   = toggle (auto -> forced opposite -> auto)
//   right  = status popup with Auto / Day / Night
//   middle = refresh
BarWidget {
  id: root
  moduleName: "varantha.sunsetr"

  readonly property var service: bar?.shell?.serviceFor("varantha.sunsetr") ?? null
  readonly property string dayPreset: String(setting("dayPreset", "day"))
  readonly property string nightPreset: String(setting("nightPreset", "night"))
  readonly property int intervalSeconds: Math.max(5, Number(setting("interval", 30)) || 30)
  // "hover"  = like the stock indicators: hidden while off, revealed while the
  //            centre section is hovered (bar.centerSectionRevealHeld)
  // "always" = always visible, dimmed while off
  // "never"  = collapsed while off, no hover reveal
  readonly property string reveal: String(setting("reveal", "hover"))

  readonly property bool serviceReady: !!service && service.stateLoaded
  readonly property bool running: serviceReady && service.running
  readonly property bool active: serviceReady && service.enabled
  readonly property bool forced: serviceReady && service.forced
  readonly property string summary: service ? service.summary : "sunsetr service not loaded"
  readonly property string lastError: service ? service.lastError : ""

  property bool popupOpen: false
  readonly property bool opened: popupOpen

  // Services get no shell.json settings of their own; forward ours.
  function pushSettings() {
    if (!service) return
    service.dayPreset = dayPreset
    service.nightPreset = nightPreset
    service.pollInterval = intervalSeconds
  }
  onServiceChanged: pushSettings()
  onDayPresetChanged: pushSettings()
  onNightPresetChanged: pushSettings()
  onIntervalSecondsChanged: pushSettings()
  Component.onCompleted: pushSettings()

  function refresh() { if (service) service.refresh() }
  function toggle() { if (service) service.toggle() }
  function open() { popupOpen = true; refresh() }
  function close() { popupOpen = false }
  function togglePopup() { if (popupOpen) close(); else open() }

  readonly property string mode: !serviceReady ? "" : (service.preset === "default" ? "default"
    : service.preset === dayPreset ? dayPreset
    : service.preset === nightPreset ? nightPreset : service.preset)

  readonly property bool centerRevealed: !!bar && bar.centerSectionRevealHeld === true && bar.centerHoverRevealSuppressed !== true
  readonly property bool inactiveRevealed: !active && (reveal === "always" || (reveal === "hover" && (centerRevealed || button.tooltipHovered)))
  readonly property bool collapsed: !active && !popupOpen && !inactiveRevealed
  implicitWidth: collapsed ? 0 : button.implicitWidth
  implicitHeight: button.implicitHeight
  clip: true

  IpcHandler {
    target: "varantha.sunsetr"
    function refresh(): void { root.broadcast("refresh") }
    function toggle(): void { root.toggle() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function debug(): string {
      return JSON.stringify({
        hasBar: !!root.bar, hasShell: !!(root.bar && root.bar.shell), hasService: !!root.service,
        serviceReady: root.serviceReady, active: root.active, reveal: root.reveal,
        centerRevealed: root.centerRevealed, collapsed: root.collapsed,
        implicitWidth: root.implicitWidth, width: root.width, height: root.height,
        buttonVisible: button.visible, buttonWidth: button.implicitWidth, opacity: root.opacity, visible: root.visible
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    visible: !root.collapsed
    // Same treatment as the stock indicators: full when on, 0.45 while peeked.
    opacity: root.active ? 1 : 0.45
    text: "󰔎"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    dimmed: !root.active
    tooltipText: root.popupOpen ? "" : (root.lastError ? "sunsetr: " + root.lastError : root.summary)

    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePopup()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    // contentWidth is the whole card (padding + border included), so size it
    // from the natural width of the widest content. Rows are not width-bound
    // to the column, so `rows.implicitWidth` is their natural width; using
    // `column.implicitWidth` here would be circular and leave long values
    // ("05:39:54 (in 8h17m)") running into the edge.
    readonly property int horizontalInset: padding * 2 + Border.left(borderSpec) + Border.right(borderSpec)
    contentWidth: popup.fittedContentWidth(Math.max(Style.space(240),
      Math.max(rows.implicitWidth, buttons.implicitWidth) + popup.horizontalInset))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "󰔎  Night Light"
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Column {
        id: rows
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: root.running ? [
            { k: "Period", v: root.service.period || "—" },
            { k: "Temperature", v: root.service.temperature !== null ? root.service.temperature + "K" : "—" },
            { k: "Gamma", v: root.service.gamma !== null ? root.service.gamma + "%" : "—" },
            { k: "Preset", v: root.service.preset || "default" },
            { k: "Next period", v: root.service.nextPeriod || "—" }
          ] : [
            { k: "sunsetr", v: root.serviceReady ? "not running" : "loading…" }
          ]

          Row {
            required property var modelData
            spacing: Style.space(8)

            Text {
              width: Style.space(96)
              text: modelData.k
              color: Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              text: modelData.v
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      Text {
        visible: root.lastError !== ""
        width: parent.width
        text: root.lastError
        color: Color.muted
        wrapMode: Text.WordWrap
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { width: parent.width }

      ButtonGroup {
        id: buttons
        anchors.horizontalCenter: parent.horizontalCenter
        focusable: false
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        fontSize: Style.font.bodySmall
        options: [
          { value: "default", label: "Auto", icon: "󰔎" },
          { value: root.dayPreset, label: "Day", icon: "󰖨" },
          { value: root.nightPreset, label: "Night", icon: "󰖔" }
        ]
        value: root.mode
        onChanged: function(v) { if (root.service) root.service.applyPreset(v) }
      }

      Text {
        visible: root.serviceReady && !root.running
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Any choice above starts sunsetr."
        color: Color.muted
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
