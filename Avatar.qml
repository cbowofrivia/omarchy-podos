import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// A sender's PodOS avatar from the helper's local cache, or the first
// letter of their name on a disc when there is none. Built like the
// Elsewhen plugin's avatar.
Item {
  id: avatar

  property string name: ""
  // Local cached file path from podos-notify, "" for none.
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

  Item {
    id: disc
    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "black"
    }
  }

  MultiEffect {
    anchors.fill: parent
    visible: avatar.pictured
    source: picture
    maskEnabled: true
    maskSource: disc
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }
}
