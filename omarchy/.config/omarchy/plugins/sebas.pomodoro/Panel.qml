import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "sebas.pomodoro"
  ipcTarget: "sebas.pomodoro"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- state ---------------------------------------------------------
  // phase: idle | focus | break | review
  property string phase: "idle"
  property string task: ""
  property int sessionId: 0
  property int endsAt: 0
  property bool paused: false
  property int pausedRemaining: 0
  property int remaining: 0
  property int parkedCount: 0
  property int totalSec: 0
  property string hint: ""

  // review + history
  property int reviewId: 0
  property var reviewParked: []
  property var todayRows: []
  property var recentTasks: []
  property int todayCount: 0
  property int todaySecs: 0
  property bool ready: false

  readonly property int focusMin: Number(setting("focusMinutes", 25))
  readonly property int breakMin: Number(setting("breakMinutes", 5))
  readonly property int cycleLength: 4
  readonly property int doneInCycle: todayCount % cycleLength
  readonly property bool running: phase === "focus" || phase === "break"
  readonly property string dbPath: Quickshell.env("HOME") + "/.local/share/omarchy-pomodoro/pomodoro.db"

  function now() { return Math.floor(Date.now() / 1000) }

  // ---- sqlite --------------------------------------------------------
  // Every statement runs through the sqlite3 CLI as a plain argv (no shell
  // interpolation); values are quoted with Model.esc().
  Component {
    id: sqlComponent
    Process {
      id: proc
      property var done: null
      stdout: StdioCollector { id: collector }
      onExited: {
        if (proc.done) proc.done(Model.parseRows(collector.text))
        proc.destroy()
      }
    }
  }

  function db(sql, done) {
    var p = sqlComponent.createObject(root, {
      command: ["bash", "-c", 'mkdir -p "$(dirname "$1")" && sqlite3 -json "$1" "$2"', "_", root.dbPath, sql],
      done: done || null
    })
    p.running = true
  }

  // Push finished sessions to the other devices right away (no-op when the
  // pomodoro-sync timer isn't installed).
  function syncNow() {
    Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "pomodoro-sync.service"])
  }

  function notify(title, body) {
    Quickshell.execDetached([Quickshell.env("OMARCHY_PATH") + "/bin/omarchy-notification-send", title, body || ""])
  }

  // ---- lifecycle -----------------------------------------------------
  Component.onCompleted: {
    db("CREATE TABLE IF NOT EXISTS sessions(id INTEGER PRIMARY KEY, task TEXT, planned_sec INTEGER, started_at INTEGER, ended_at INTEGER, status TEXT, note TEXT);" +
       "CREATE TABLE IF NOT EXISTS parked(id INTEGER PRIMARY KEY, session_id INTEGER, text TEXT, created_at INTEGER);" +
       "CREATE TABLE IF NOT EXISTS kv(key TEXT PRIMARY KEY, value TEXT);" +
       "CREATE TABLE IF NOT EXISTS sessions_remote(device TEXT, id INTEGER, task TEXT, planned_sec INTEGER, started_at INTEGER, ended_at INTEGER, status TEXT, note TEXT, PRIMARY KEY(device, id));" +
       "SELECT value FROM kv WHERE key='active';",
       function(rows) {
         root.ready = true
         if (rows.length) root.restore(rows[0].value)
         root.refreshHistory()
       })
  }

  function persistActive() {
    var s = root.phase === "focus" || root.phase === "break" ? JSON.stringify({
      phase: root.phase, task: root.task, sessionId: root.sessionId, endsAt: root.endsAt,
      paused: root.paused, pausedRemaining: root.pausedRemaining, totalSec: root.totalSec, parkedCount: root.parkedCount
    }) : ""
    db("INSERT OR REPLACE INTO kv(key,value) VALUES('active','" + Model.esc(s) + "');")
  }

  function restore(json) {
    var s = null
    try { s = JSON.parse(json) } catch (e) {}
    if (!s || !s.phase) return
    root.phase = s.phase; root.task = s.task || ""; root.sessionId = s.sessionId || 0
    root.endsAt = s.endsAt || 0; root.paused = s.paused === true
    root.pausedRemaining = s.pausedRemaining || 0
    root.totalSec = s.totalSec || (s.phase === "break" ? root.breakMin : root.focusMin) * 60
    root.parkedCount = s.parkedCount || 0
    tick()
  }

  function refreshHistory() {
    var since = Model.startOfToday()
    db("SELECT task, planned_sec, started_at, ended_at, status, '' AS device FROM sessions WHERE started_at >= " + since +
       " UNION ALL SELECT task, planned_sec, started_at, ended_at, status, device FROM sessions_remote WHERE started_at >= " + since +
       " ORDER BY started_at DESC LIMIT 6;", function(rows) {
      root.todayRows = rows
    })
    db("SELECT COUNT(*) AS n, COALESCE(SUM(ended_at - started_at),0) AS secs FROM (" +
       "SELECT started_at, ended_at FROM sessions WHERE started_at >= " + since + " AND status='completed' UNION ALL " +
       "SELECT started_at, ended_at FROM sessions_remote WHERE started_at >= " + since + " AND status='completed');", function(rows) {
      if (rows.length) { root.todayCount = rows[0].n; root.todaySecs = rows[0].secs }
    })
    db("SELECT task FROM (SELECT task, started_at FROM sessions UNION ALL SELECT task, started_at FROM sessions_remote) " +
       "WHERE task != '' GROUP BY task ORDER BY MAX(started_at) DESC LIMIT 4;", function(rows) {
      root.recentTasks = rows.map(function(r) { return r.task })
    })
  }

  function startFocus(rawTask) {
    var minutes = root.focusMin
    var name = String(rawTask || "").trim()
    if (name === "" && setting("requireTask", true) !== false) {
      root.hint = "Name the one thing you're working on."
      return
    }
    root.hint = ""
    var started = now()
    root.task = name
    root.phase = "focus"
    root.paused = false
    root.totalSec = minutes * 60
    root.endsAt = started + minutes * 60
    root.parkedCount = 0
    tick()
    db("INSERT INTO sessions(task, planned_sec, started_at, status) VALUES('" + Model.esc(name) + "'," + (minutes * 60) + "," + started + ",'running');" +
       "SELECT last_insert_rowid() AS id;", function(rows) {
      if (rows.length) root.sessionId = rows[0].id
      root.persistActive()
    })
  }

  function startBreak() {
    root.phase = "break"
    root.paused = false
    root.task = "Rest"
    root.sessionId = 0
    root.totalSec = root.breakMin * 60
    root.endsAt = now() + root.totalSec
    tick()
    persistActive()
  }

  function closeSession(status) {
    db("UPDATE sessions SET status='" + status + "', ended_at=" + now() + " WHERE id=" + root.sessionId + ";", function() { root.refreshHistory(); root.syncNow() })
  }

  function complete() {
    if (root.phase === "focus") {
      closeSession("completed")
      root.todayCount += 1
      root.reviewId = root.sessionId
      root.reviewParked = []
      if (root.parkedCount > 0)
        db("SELECT text FROM parked WHERE session_id=" + root.sessionId + " ORDER BY id;", function(rows) { root.reviewParked = rows.map(function(r) { return r.text }) })
      root.notify("Focus session done", root.task)
      if (setting("askLog", true) !== false) {
        root.phase = "review"
        persistActive()
        if (!root.opened) root.open()
      } else {
        startBreak()
      }
    } else if (root.phase === "break") {
      root.notify("Break over", "Ready for the next one?")
      root.phase = "idle"; root.task = ""
      persistActive()
    }
  }

  function stop() {
    if (root.phase === "focus") closeSession("abandoned")
    root.phase = "idle"; root.task = ""; root.paused = false
    persistActive()
  }

  function togglePause() {
    if (!root.running) return
    if (root.paused) {
      root.endsAt = now() + root.pausedRemaining
      root.paused = false
    } else {
      root.pausedRemaining = Math.max(0, root.endsAt - now())
      root.paused = true
    }
    tick()
    persistActive()
  }

  function finishReview(note, withBreak) {
    var n = String(note || "").trim()
    if (n !== "") db("UPDATE sessions SET note='" + Model.esc(n) + "' WHERE id=" + root.reviewId + ";", function() { root.refreshHistory(); root.syncNow() })
    if (withBreak) startBreak()
    else { root.phase = "idle"; root.task = ""; persistActive() }
    noteField.text = ""
  }

  function park(text) {
    var t = String(text || "").trim()
    if (t === "") return
    root.parkedCount += 1
    db("INSERT INTO parked(session_id, text, created_at) VALUES(" + root.sessionId + ",'" + Model.esc(t) + "'," + now() + ");")
    persistActive()
  }

  function tick() {
    root.remaining = root.paused ? root.pausedRemaining : Math.max(0, root.endsAt - now())
    if (root.running && !root.paused && root.remaining <= 0) complete()
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.running && !root.paused
    onTriggered: root.tick()
  }

  // ---- bar -----------------------------------------------------------
  function label() {
    if (phase === "focus") return (paused ? "\uDB80\uDFE4 " : "\uDB81\uDD1B ") + Model.clock(remaining)
    if (phase === "break") return "\uDB80\uDD76 " + Model.clock(remaining)
    if (phase === "review") return "\uDB80\uDD2C"
    return "\uDB81\uDD1B"
  }

  function focusField() {
    if (phase === "idle") taskField.forceActiveFocus()
    else if (phase === "review") noteField.forceActiveFocus()
  }

  onOpenedChanged: if (opened) { hint = ""; refreshHistory(); Qt.callLater(focusField) }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label()
    active: root.phase === "review"
    tooltipText: root.running ? root.task : (root.phase === "review" ? "Log your session" : "Start a pomodoro")
    onPressed: function(b) {
      if (b === Qt.RightButton && root.running) root.togglePause()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: taskField.activeFocus || noteField.activeFocus || parkField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(10)

          // ---- idle: declare the one thing -------------------------
          Column {
            visible: root.phase === "idle"
            width: parent.width
            spacing: Style.space(10)

            PanelHero {
              width: parent.width
              title: "Focus"
              meta: root.focusMin + " min focus · " + root.breakMin + " min rest" + (root.todayCount > 0 ? " · " + root.todayCount + " today" : "")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              id: taskField
              width: parent.width
              foreground: root.foreground
              placeholderText: "The ONE thing for this session"
              onAccepted: root.startFocus(text)
              onTextChanged: root.hint = ""
              Keys.onEscapePressed: root.close()
            }

            Flow {
              visible: root.recentTasks.length > 0
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.recentTasks
                delegate: Button {
                  required property string modelData
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  text: modelData
                  onClicked: { taskField.text = modelData; taskField.forceActiveFocus() }
                }
              }
            }

            Text {
              visible: root.hint !== ""
              width: parent.width
              text: root.hint
              color: bar ? bar.urgent : Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              width: parent.width
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              text: "Start focus"
              onClicked: root.startFocus(taskField.text)
            }

            PanelSeparator { visible: root.todayRows.length > 0; foreground: root.foreground }
            PanelSectionHeader { visible: root.todayRows.length > 0; text: "TODAY"; foreground: root.foreground; fontFamily: root.fontFamily }

            Repeater {
              model: root.todayRows
              delegate: Text {
                required property var modelData
                width: panelColumn.width
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: modelData.status === "completed" ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                text: (modelData.status === "completed" ? "✓ " : modelData.status === "running" ? "… " : "✗ ") +
                      (modelData.task || "(untitled)") +
                      (modelData.ended_at ? "  ·  " + Model.duration(modelData.ended_at - modelData.started_at) : "") +
                      (modelData.device ? "  ·  " + modelData.device : "")
              }
            }
          }

          // ---- focus / break ----------------------------------------
          Column {
            visible: root.running
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: root.phase === "focus" ? "FOCUSING ON" : "BREAK"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.task
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Item {
              width: parent.width
              height: Style.space(190)

              Canvas {
                id: ring
                width: Style.space(170)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                renderTarget: Canvas.Image
                property real progress: root.totalSec > 0 ? 1 - root.remaining / root.totalSec : 0
                property color trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
                property color arcColor: root.phase === "break" ? Color.accent : root.foreground
                onProgressChanged: requestPaint()
                onArcColorChanged: requestPaint()
                onTrackColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  var lw = Style.space(7)
                  var c = width / 2
                  var r = c - lw
                  ctx.lineWidth = lw
                  ctx.lineCap = "round"
                  ctx.strokeStyle = trackColor
                  ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke()
                  if (progress > 0.002) {
                    ctx.strokeStyle = arcColor
                    ctx.beginPath()
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, progress))
                    ctx.stroke()
                  }
                }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Model.clock(root.remaining)
                    color: root.paused ? root.dim : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display * 1.6
                    font.bold: true
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.paused
                    text: "paused"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)
              visible: root.phase === "focus"
              Repeater {
                model: root.cycleLength
                delegate: Rectangle {
                  required property int index
                  width: Style.space(10); height: width; radius: width / 2
                  color: index < root.doneInCycle ? root.foreground
                       : index === root.doneInCycle ? Color.accent : "transparent"
                  border.width: 1
                  border.color: index <= root.doneInCycle ? "transparent" : root.dim
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Button {
                width: (parent.width - parent.spacing) / 2
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                text: root.paused ? "Resume" : "Pause"
                onClicked: root.togglePause()
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                text: root.phase === "focus" ? "Abandon" : "Skip break"
                onClicked: root.stop()
              }
            }

            PanelSeparator { visible: root.phase === "focus"; foreground: root.foreground }
            PanelSectionHeader {
              visible: root.phase === "focus"
              text: "PARKING LOT" + (root.parkedCount > 0 ? " (" + root.parkedCount + ")" : "")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            TextField {
              id: parkField
              visible: root.phase === "focus"
              width: parent.width
              foreground: root.foreground
              placeholderText: "Distracting idea? Park it, keep going"
              onAccepted: { root.park(text); text = "" }
              Keys.onEscapePressed: root.close()
            }
          }

          // ---- review: log what happened ----------------------------
          Column {
            visible: root.phase === "review"
            width: parent.width
            spacing: Style.space(10)

            PanelHero {
              width: parent.width
              title: "Session done"
              meta: root.task
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            PanelSectionHeader { visible: root.reviewParked.length > 0; text: "PARKED"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.reviewParked
              delegate: Text {
                required property string modelData
                width: panelColumn.width
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                text: "• " + modelData
              }
            }

            TextField {
              id: noteField
              width: parent.width
              foreground: root.foreground
              placeholderText: "What did you get done? (optional)"
              onAccepted: root.finishReview(text, true)
              Keys.onEscapePressed: root.close()
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Button {
                width: (parent.width - parent.spacing) / 2
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                text: "Save & break"
                onClicked: root.finishReview(noteField.text, true)
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                text: "Save & skip"
                onClicked: root.finishReview(noteField.text, false)
              }
            }
          }
        }
      }
    }
  }
}
