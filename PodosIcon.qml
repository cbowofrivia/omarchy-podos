import QtQuick
import qs.Commons
import qs.Commons as Commons

// The PodOS mark: four nested rings stacked toward the bottom, each one
// cut by the ring inside it, on a 100-unit grid like the PodOS logo.
// Drawn in one colour so it follows
// the Omarchy theme.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Commons.Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  onColorChanged: canvas.requestPaint()
  onIconSizeChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var s = Math.min(width, height) / 100
      var count = 4, thickness = 11, gap = 1.5
      var firstR = 46, lastR = 18, firstY = 46, lastY = 82
      var rings = []
      for (var i = 0; i < count; i++) {
        rings.push({
          y: firstY + (lastY - firstY) / (count - 1) * i,
          r: firstR - (firstR - lastR) / (count - 1) * i
        })
      }
      ctx.lineWidth = thickness * s
      for (var j = 0; j < count; j++) {
        var ring = rings[j]
        ctx.globalCompositeOperation = "source-over"
        ctx.strokeStyle = root.color
        ctx.beginPath()
        ctx.arc(50 * s, ring.y * s, (ring.r - thickness / 2) * s, 0, Math.PI * 2)
        ctx.stroke()
        if (j < count - 1) {
          // Cut the space the next ring sits in, like the SVG mask.
          var next = rings[j + 1]
          ctx.globalCompositeOperation = "destination-out"
          ctx.beginPath()
          ctx.arc(50 * s, next.y * s, (next.r + gap) * s, 0, Math.PI * 2)
          ctx.fill()
        }
      }
      ctx.globalCompositeOperation = "source-over"
    }
  }
}
