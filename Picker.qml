import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SessionModel.js" as Model

// Summoned picker (same surface and keys as the built-in emoji picker). Lists the Claude Code
// sessions started from the phone and opens the chosen one in a new terminal tab.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "stewartjarod.phone-sessions"
  readonly property string scriptDir: decodeURIComponent(
    Qt.resolvedUrl("scripts").toString().replace(/^file:\/\//, ""))

  property bool opened: false
  property bool loading: false
  property string filterText: ""
  property int selectedIndex: 0
  property var sessions: []
  property var shown: []
  property real nowSec: Date.now() / 1000

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int footerHeight: Style.font.caption + Style.spacing.sm
  property int rowHeight: Style.font.title + Style.font.caption + Style.spacing.controlPaddingY * 2 + Style.spacing.xxs
  property int cardWidth: Math.min(Style.space(640), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(480), panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refresh() {
    if (lister.running) return
    root.loading = true
    lister.command = [root.scriptDir + "/list-sessions"]
    lister.running = true
  }

  function loaded(raw) {
    root.loading = false
    root.nowSec = Date.now() / 1000
    root.sessions = Model.parse(raw)
    root.rebuild()
  }

  function rebuild() {
    root.shown = Model.filter(root.sessions, root.filterText)
    if (root.selectedIndex >= root.shown.length) root.selectedIndex = Math.max(0, root.shown.length - 1)
    Qt.callLater(function() { if (root.shown.length > 0) list.positionViewAtIndex(root.selectedIndex, ListView.Contain) })
  }

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.rebuild()
  }

  function move(delta) {
    if (root.shown.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.shown.length) % root.shown.length
    list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function activate(index) {
    var s = root.shown[index]
    if (!s) return
    // Close first so the overlay gives keyboard focus back before the terminal is typed into.
    root.dismiss()
    Quickshell.execDetached([root.scriptDir + "/open-session", s.cwd, s.id])
  }

  Process {
    id: lister
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loaded(text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "phone-sessions"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while summoned, like the built-in pickers; the window is unmapped when closed.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
            root.move(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
            root.move(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(root.selectedIndex)
            event.accepted = true
          } else if (!ctrl && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: count.left
            anchors.rightMargin: root.contentSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || "Phone sessions…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: count
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.loading ? "…" : String(root.shown.length)
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.footerHeight - root.contentSpacing * 2

          ListView {
            id: list
            anchors.fill: parent
            model: root.shown
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              id: row
              required property int index
              required property var modelData
              readonly property bool hasCursor: index === root.selectedIndex

              width: ListView.view.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.spacing.rowPaddingX
                anchors.rightMargin: Style.spacing.rowPaddingX
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spacing.xxs

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: Model.label(row.modelData)
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  // A live session is still running on the phone side; opening it here stops that.
                  text: row.modelData.folder + "  ·  " + Model.ago(row.modelData.mtime, root.nowSec)
                        + (row.modelData.live ? "  ·  running on phone" : "")
                  color: row.modelData.live ? root.selectedText : root.foreground
                  opacity: row.modelData.live ? 0.9 : 0.58
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.selectedIndex = row.index
                onClicked: root.activate(row.index)
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: !root.loading && root.shown.length === 0
            textFormat: Text.PlainText
            text: root.filterText ? "No matches for “" + root.filterText + "”" : "No phone sessions yet"
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }

        Text {
          width: parent.width
          height: root.footerHeight
          textFormat: Text.PlainText
          text: "↑↓ select  ·  Enter open in terminal  ·  type to filter  ·  Esc close"
          color: root.foreground
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
