pragma Singleton
import QtQuick
QtObject {
  id: root
  property color foreground: "#fff"
  readonly property QtObject popups: QtObject {
    property color text: "#fff"
  }
}
