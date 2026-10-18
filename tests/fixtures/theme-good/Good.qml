import QtQuick
import qs.Commons

// color: "#ff0000" in a comment is fine
Rectangle {
  color: "transparent"
  border.color: Util.alpha(Color.foreground, 0.4)
  radius: Style.cornerRadius
  Rectangle { color: "#4caf7a"; width: 8; height: 8 } // theme-ok: fixed status LED
  Text {
    color: Color.foreground
    font.pixelSize: Style.font.size
    font.family: Style.font.family
  }
}
