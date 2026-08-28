import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property string phase: "idle"
  property string promptText: ""
  property string responseText: ""
  property string errorText: ""
  property real audioPeak: 0
  property var waveform: []
  property int animationFrame: 0

  readonly property color phaseColor: phase === "listening" ? "#73daca"
    : phase === "transcribing" ? "#e0af68"
    : phase === "thinking" ? "#7aa2f7"
    : phase === "speaking" ? "#bb9af7"
    : phase === "error" ? "#f7768e" : Color.accent

  function setPhase(payloadJson) {
    try {
      var payload = JSON.parse(payloadJson || "{}")
      phase = String(payload.phase || "idle")
      promptText = String(payload.prompt || "")
      responseText = String(payload.response || "")
      errorText = String(payload.error || "")
      opened = phase !== "idle"
      if (phase !== "listening") {
        waveform = []
        audioPeak = 0
      }
    } catch (e) {
      phase = "error"
      errorText = "Invalid assistant state"
      opened = true
    }
  }

  function open(payloadJson) {
    if (payloadJson && payloadJson !== "{}") setPhase(payloadJson)
    else opened = true
  }

  function close() {
    opened = false
    phase = "idle"
  }

  IpcHandler {
    target: "sarrietav-dev.omassistant"
    function setState(payloadJson: string): string {
      root.setPhase(payloadJson)
      return "ok"
    }
    function show(): string { root.opened = true; return "ok" }
    function hide(): string { root.close(); return "ok" }
    function ping(): string { return "ok" }
  }

  Process {
    id: audioBridge
    command: ["voxtype-audio-bridge"]
    running: root.phase === "listening"
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        try {
          var frame = JSON.parse(String(line).trim())
          if (typeof frame.peak !== "number") return
          root.audioPeak = frame.peak
          var next = root.waveform.slice()
          next.push(Math.min(1, frame.peak * 7))
          while (next.length > 32) next.shift()
          root.waveform = next
          wave.requestPaint()
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 150
    running: root.opened
    repeat: true
    onTriggered: {
      root.animationFrame++
      figure.requestPaint()
      wave.requestPaint()
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omassistant"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    BorderSurface {
      id: card
      width: 390
      height: 224
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.space(46)
      anchors.rightMargin: Style.space(24)
      color: Util.alpha(Color.background, 0.96)
      borderSpec: Border.surfaceSpec("popups", "border", root.phaseColor, Math.max(1, Style.space(2)))
      radius: 4
      opacity: root.opened ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 120 } }

      Item {
        anchors.fill: parent
        anchors.margins: Style.space(16)

        Canvas {
          id: figure
          width: 120
          height: 154
          anchors.left: parent.left
          anchors.top: parent.top

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var px = 6
            var bob = (root.phase === "thinking" || root.phase === "speaking")
              ? Math.round(Math.sin(root.animationFrame * 0.8) * 2) : 0
            function block(x, y, w, h, color) {
              ctx.fillStyle = color
              ctx.fillRect(x * px, y * px + bob, w * px, h * px)
            }

            // Pixel helper: oversized head, tiny useful body, and a glowing chest light.
            block(5, 1, 10, 1, root.phaseColor)
            block(3, 2, 14, 2, Color.popups.text)
            block(2, 4, 16, 8, Color.popups.text)
            block(3, 12, 14, 2, Color.popups.text)
            block(4, 4, 12, 7, Color.background)
            block(5, 6, 2, 2, root.phaseColor)
            block(13, 6, 2, 2, root.phaseColor)

            var mouthOpen = root.phase === "speaking" && root.animationFrame % 2 === 0
            if (mouthOpen) block(8, 9, 4, 2, root.phaseColor)
            else block(8, 10, 4, 1, root.phaseColor)

            block(7, 14, 6, 2, Color.popups.text)
            block(5, 16, 10, 6, Color.popups.text)
            block(3, 17, 2, 5, Color.popups.text)
            block(15, 17, 2, 5, Color.popups.text)
            block(8, 17, 4, 3, Color.background)
            block(9, 18, 2, 1, root.phaseColor)
            block(6, 22, 3, 3, Color.popups.text)
            block(11, 22, 3, 3, Color.popups.text)

            if (root.phase === "thinking") {
              block(17, 1 + root.animationFrame % 3, 1, 1, root.phaseColor)
              block(19, 0 + (root.animationFrame + 1) % 3, 1, 1, root.phaseColor)
            }
          }
        }

        Text {
          anchors.top: parent.top
          anchors.left: figure.right
          anchors.leftMargin: Style.space(12)
          text: root.phase === "listening" ? "LISTENING"
            : root.phase === "transcribing" ? "TRANSCRIBING"
            : root.phase === "thinking" ? "THINKING"
            : root.phase === "speaking" ? "SPEAKING"
            : root.phase === "error" ? "SYSTEM ERROR" : "READY"
          color: root.phaseColor
          font.family: Style.font.family
          font.bold: true
          font.pixelSize: Style.font.title
          font.letterSpacing: 2
        }

        Canvas {
          id: wave
          width: 222
          height: 42
          anchors.left: figure.right
          anchors.leftMargin: Style.space(12)
          anchors.top: parent.top
          anchors.topMargin: Style.space(34)

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = root.phaseColor
            var bars = root.waveform
            var count = 32
            var gap = 3
            var barWidth = (width - gap * (count - 1)) / count
            for (var i = 0; i < count; i++) {
              var value = i < bars.length ? bars[i] : 0.05
              if (root.phase !== "listening")
                value = 0.12 + 0.1 * Math.abs(Math.sin((i + root.animationFrame) * 0.45))
              var h = Math.max(2, value * height)
              ctx.fillRect(i * (barWidth + gap), (height - h) / 2, barWidth, h)
            }
          }
        }

        Text {
          width: 222
          anchors.left: figure.right
          anchors.leftMargin: Style.space(12)
          anchors.top: wave.bottom
          anchors.topMargin: Style.space(10)
          text: root.phase === "error" ? root.errorText
            : root.phase === "speaking" ? root.responseText
            : root.promptText !== "" ? root.promptText
            : root.phase === "listening" ? "Press F10 again when you are done."
            : "One moment..."
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: 5
        }

        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          text: "F10  SUBMIT / CANCEL"
          color: Util.alpha(Color.popups.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }
      }
    }
  }
}
