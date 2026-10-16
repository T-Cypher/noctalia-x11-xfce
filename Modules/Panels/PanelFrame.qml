import QtQuick
import QtQuick.Shapes
import qs.Commons

// Panel surface. Floating panels: rounded rectangle with outline border.
// Attached panels: borderless body with noctalia's concave "flare" corners where the panel
// meets the bar edge (attachEdge = top | bottom | left | right).
Item {
    id: root

    property string attachEdge: ""
    property real radius: Style.radiusXl
    property color fill: Theme.surface
    property color borderColor: Theme.outline
    property real borderWidth: Style.borderWidth

    readonly property bool attached: attachEdge !== ""
    readonly property real flare: attached ? Math.min(radius, (attachEdge === "top" || attachEdge === "bottom") ? height : width) : 0

    Rectangle {
        anchors.fill: parent
        visible: !root.attached
        radius: root.radius
        color: root.fill
        border.color: root.borderColor
        border.width: root.borderWidth
    }

    Shape {
        id: shape
        visible: root.attached
        x: -root.flare
        y: -root.flare
        width: root.width + root.flare * 2
        height: root.height + root.flare * 2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: root.fill
            PathSvg {
                path: root.svgPath(root.attachEdge, root.width, root.height, Math.min(root.radius, root.width / 2, root.height / 2), root.flare, root.flare)
            }
        }
    }

    // SVG path for an attached panel body at offset o with convex radius R and concave flare r.
    function svgPath(edge, w, h, R, r, o) {
        function p(x, y) {
            return (x + o).toFixed(2) + " " + (y + o).toFixed(2);
        }
        if (w <= 0 || h <= 0)
            return "";
        var s = "";
        switch (edge) {
        case "top":
            s = "M " + p(-r, 0) + " L " + p(w + r, 0) + " A " + r + " " + r + " 0 0 0 " + p(w, r) + " L " + p(w, h - R) + " A " + R + " " + R + " 0 0 1 " + p(w - R, h) + " L " + p(R, h) + " A " + R + " " + R + " 0 0 1 " + p(0, h - R) + " L " + p(0, r) + " A " + r + " " + r + " 0 0 0 " + p(-r, 0) + " Z";
            break;
        case "bottom":
            s = "M " + p(-r, h) + " A " + r + " " + r + " 0 0 0 " + p(0, h - r) + " L " + p(0, R) + " A " + R + " " + R + " 0 0 1 " + p(R, 0) + " L " + p(w - R, 0) + " A " + R + " " + R + " 0 0 1 " + p(w, R) + " L " + p(w, h - r) + " A " + r + " " + r + " 0 0 0 " + p(w + r, h) + " Z";
            break;
        case "left":
            s = "M " + p(0, -r) + " A " + r + " " + r + " 0 0 0 " + p(r, 0) + " L " + p(w - R, 0) + " A " + R + " " + R + " 0 0 1 " + p(w, R) + " L " + p(w, h - R) + " A " + R + " " + R + " 0 0 1 " + p(w - R, h) + " L " + p(r, h) + " A " + r + " " + r + " 0 0 0 " + p(0, h + r) + " Z";
            break;
        case "right":
            s = "M " + p(w, -r) + " L " + p(w, h + r) + " A " + r + " " + r + " 0 0 0 " + p(w - r, h) + " L " + p(R, h) + " A " + R + " " + R + " 0 0 1 " + p(0, h - R) + " L " + p(0, R) + " A " + R + " " + R + " 0 0 1 " + p(R, 0) + " L " + p(w - r, 0) + " A " + r + " " + r + " 0 0 0 " + p(w, -r) + " Z";
            break;
        }
        return s;
    }
}
