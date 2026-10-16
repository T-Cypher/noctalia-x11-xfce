import QtQuick
import qs.Commons

// Area graph for system monitor histories.
Canvas {
    id: root

    property var values: []
    property real maxValue: 100
    property bool autoScale: false
    property color lineColor: Theme.primary
    property int capacity: 60

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var v = values || [];
        if (v.length < 2 || width <= 0 || height <= 0)
            return;
        var max = maxValue;
        if (autoScale) {
            max = 1;
            for (var k = 0; k < v.length; k++)
                max = Math.max(max, v[k]);
            max *= 1.15;
        }
        var stepX = width / Math.max(1, capacity - 1);
        var offset = (capacity - v.length) * stepX;
        ctx.beginPath();
        for (var i = 0; i < v.length; i++) {
            var x = offset + i * stepX;
            var y = height - (Math.min(max, v[i]) / max) * (height - 2) - 1;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.lineTo(offset + (v.length - 1) * stepX, height);
        ctx.lineTo(offset, height);
        ctx.closePath();
        var grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.35));
        grad.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.02));
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
