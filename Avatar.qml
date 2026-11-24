import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons

// A sender's PodOS avatar from the helper's local cache, or the first
// letter of their name on a disc when there is none.
//
// The photo is painted straight into a circular Shape (fillItem), with no
// layer or MultiEffect mask. One MultiEffect per row left GPU work behind
// that grew with every panel rebuild, and closing the panel then froze the
// whole shell (bar and notifications) for 10-25 seconds.
Item {
  id: avatar

  property string name: ""
  // Local cached file path from omarchy-podos-fetch, "" for none.
  property string source: ""
  property real size: Style.space(28)
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  readonly property bool pictured: picture.status === Image.Ready
  readonly property string initial: {
    var text = String(name || "").replace(/^[^A-Za-z0-9]+/, "")
    return text.length > 0 ? text.charAt(0).toUpperCase() : "?"
  }

  implicitWidth: size
  implicitHeight: size

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Qt.rgba(avatar.foreground.r, avatar.foreground.g, avatar.foreground.b, 0.18)
    visible: !avatar.pictured

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: avatar.initial
      color: avatar.foreground
      font.family: avatar.fontFamily
      font.pixelSize: Math.round(avatar.size * 0.5)
      font.weight: Font.DemiBold
    }
  }

  Image {
    id: picture
    anchors.fill: parent
    visible: false
    source: /^\/[A-Za-z0-9._\/-]+$/.test(avatar.source) ? "file://" + avatar.source : ""
    sourceSize.width: Math.ceil(avatar.size * Screen.devicePixelRatio)
    sourceSize.height: Math.ceil(avatar.size * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
  }

  Shape {
    anchors.fill: parent
    visible: avatar.pictured
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: -1
      fillItem: picture
      PathAngleArc {
        centerX: avatar.width / 2
        centerY: avatar.height / 2
        radiusX: avatar.width / 2
        radiusY: avatar.height / 2
        startAngle: 0
        sweepAngle: 360
      }
    }
  }
}
