pragma Singleton
import QtQuick
QtObject {
  id: root
  function space(px) { return px }
  property int cornerRadius: 0
}
