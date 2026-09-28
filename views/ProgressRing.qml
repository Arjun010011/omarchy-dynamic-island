import QtQuick
import QtQuick.Shapes
import qs.Commons

// A thin ring that fills clockwise from 12 o'clock, drawn as vector paths
// (no offscreen layer) so it stays crisp at fractional scaling.
Item {
  id: ring

  property real progress: 0
  property color color: "white"
  property real lineWidth: 2.5

  readonly property real r: Math.max(0, Math.min(width, height) / 2 - lineWidth / 2)
  readonly property real sweep: Math.max(0, Math.min(1, progress)) * 360

  Behavior on progress { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: Util.alpha(ring.color, 0.22)
      strokeWidth: ring.lineWidth
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: ring.r; radiusY: ring.r
        startAngle: 0; sweepAngle: 360
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: ring.color
      strokeWidth: ring.lineWidth
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: ring.r; radiusY: ring.r
        startAngle: -90; sweepAngle: ring.sweep
      }
    }
  }
}
