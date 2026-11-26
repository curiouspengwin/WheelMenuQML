import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: root

    property real centerX: 0
    property real centerY: 0
    property real innerRadius: 50
    property real outerRadius: 110

    // Angles in degrees: 0 = 3 o'clock, positive = clockwise
    property real startAngle: -150
    property real endAngle: -90

    // Desired parallel gap width (in pixels) between adjacent segments
    property real gapWidth: 6

    // Visual & state properties
    property string label: ""
    property string iconSource: ""
    property color fillColor: "#23262b"
    property color hoverColor: "#323740"
    property color activeColor: "#9aa0ab"
    property color selectedColor: "#1f6feb"
    property color borderColor: "#141619"
    property color textColor: "#f0f2f5"
    property color activeTextColor: "#ffffff"

    property bool hovered: false
    property bool active: false     // e.g., primary segment whose sub-wheel is open
    property bool selected: false   // e.g., multi-selected secondary segment

    signal segmentHovered(bool isHovered)
    signal segmentClicked()

    // Compute angular offset corresponding to half of a parallel strip gap at radius r:
    // sin(deltaTheta) = (gapWidth / 2) / r
    function _angleOffsetForRadius(r) {
        if (r <= 1 || gapWidth <= 0)
            return 0;
        var halfGap = gapWidth * 0.5;
        if (halfGap >= r * 0.9)
            return 0;
        var rad = Math.asin(halfGap / r);
        return rad * 180.0 / Math.PI;
    }

    function _degToRad(deg) {
        return deg * Math.PI / 180.0;
    }

    function _pointAt(r, deg) {
        var rad = _degToRad(deg);
        return Qt.point(centerX + r * Math.cos(rad), centerY + r * Math.sin(rad));
    }

    // Ray-line intersection in 2D to trim a radial edge by a parallel normal offset
    function _intersectLines(p1, p2, p3, p4) {
        var x1 = p1.x, y1 = p1.y;
        var x2 = p2.x, y2 = p2.y;
        var x3 = p3.x, y3 = p3.y;
        var x4 = p4.x, y4 = p4.y;

        var denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
        if (Math.abs(denom) < 1e-6)
            return Qt.point(x1, y1);

        var px = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / denom;
        var py = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / denom;
        return Qt.point(px, py);
    }

    // Computes parallel-inset start/end angles at a given radius r so the perpendicular
    // distance between adjacent segments stays close to `gapWidth`.
    function _parallelAnglesAtRadius(r) {
        var totalSpan = endAngle - startAngle;
        var baseOffset = _angleOffsetForRadius(r);
        var maxOffset = Math.max(0, totalSpan * 0.45);
        var offset = Math.min(baseOffset, maxOffset);

        // Adjust slightly using radial slope so the gap is perpendicular to the edge
        // rather than purely tangential at the inner edge.
        var a0 = startAngle + offset;
        var a1 = endAngle - offset;
        return { start: a0, end: a1 };
    }

    // Exact hit-test matching the parallel-gapped wedge geometry
    function containsPoint(px, py) {
        var dx = px - centerX;
        var dy = py - centerY;
        var dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < innerRadius || dist > outerRadius)
            return false;

        var ang = Math.atan2(dy, dx) * 180.0 / Math.PI;
        var bounds = _parallelAnglesAtRadius(dist);

        // Normalize angle relative to bounds.start into [0, 360)
        var rel = ((ang - bounds.start) % 360 + 360) % 360;
        var span = bounds.end - bounds.start;
        return span > 0 && rel <= span;
    }

    // Midpoint position for placing icon + label cleanly inside the segment
    readonly property point midPoint: {
        var midR = (innerRadius + outerRadius) * 0.5;
        var midA = (startAngle + endAngle) * 0.5;
        return _pointAt(midR, midA);
    }

    readonly property color effectiveFill: {
        if (selected)
            return hovered ? Qt.lighter(selectedColor, 1.15) : selectedColor;
        if (active)
            return hovered ? Qt.lighter(activeColor, 1.08) : activeColor;
        if (hovered)
            return hoverColor;
        return fillColor;
    }

    readonly property color effectiveTextColor: (active || selected) ? activeTextColor : textColor

    Shape {
        id: wedgeShape
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            id: wedgePath
            strokeWidth: 1.5
            strokeColor: root.borderColor
            fillColor: root.effectiveFill

            property var innerBounds: root._parallelAnglesAtRadius(root.innerRadius)
            property var outerBounds: root._parallelAnglesAtRadius(root.outerRadius)

            property point pInnerStart: root._pointAt(root.innerRadius, innerBounds.start)
            property point pOuterStart: root._pointAt(root.outerRadius, outerBounds.start)
            property point pOuterEnd: root._pointAt(root.outerRadius, outerBounds.end)
            property point pInnerEnd: root._pointAt(root.innerRadius, innerBounds.end)

            startX: pInnerStart.x
            startY: pInnerStart.y

            // 1. Left/leading edge from inner radius to outer radius
            PathLine {
                x: wedgePath.pOuterStart.x
                y: wedgePath.pOuterStart.y
            }

            // 2. Outer arc
            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.outerRadius
                radiusY: root.outerRadius
                startAngle: wedgePath.outerBounds.start
                sweepAngle: Math.max(0, wedgePath.outerBounds.end - wedgePath.outerBounds.start)
                moveToStart: false
            }

            // 3. Right/trailing edge from outer radius back to inner radius
            PathLine {
                x: wedgePath.pInnerEnd.x
                y: wedgePath.pInnerEnd.y
            }

            // 4. Inner arc back to start
            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.innerRadius
                radiusY: root.innerRadius
                startAngle: wedgePath.innerBounds.end
                sweepAngle: -Math.max(0, wedgePath.innerBounds.end - wedgePath.innerBounds.start)
                moveToStart: false
            }

            PathLine {
                x: wedgePath.pInnerStart.x
                y: wedgePath.pInnerStart.y
            }
        }
    }

    // Upright icon + label centered inside the wedge
    Column {
        x: root.midPoint.x - width * 0.5
        y: root.midPoint.y - height * 0.5
        spacing: 4

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.iconSource
            visible: root.iconSource !== ""
            width: 20
            height: 20
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.effectiveTextColor
            font.pixelSize: 13
            font.weight: (root.active || root.selected || root.hovered) ? Font.DemiBold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: Math.min(84, Math.max(44, (root.outerRadius - root.innerRadius) * 0.95))
        }
    }
}