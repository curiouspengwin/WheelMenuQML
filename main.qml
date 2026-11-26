import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    width: 900
    height: 700
    visible: true
    color: "#3f4144"

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        color: "#e5e7eb"
        font.pixelSize: 14
        text: "Click center marker to open • Hover primary option (slight delay) for sub-wheel • Click sub-options to multi-select • Click outside to commit"
    }

    RadialWheelMenu {
        id: radialMenu
        arcStartAngle: -195
        arcSpanAngle: 230
        segmentGap: 7
        hoverOpenDelay: 120

        items: [
            {
                id: "change_target",
                label: "Change Target",
                subOptions: [
                    { id: "all", label: "All" },
                    { id: "current", label: "Current" },
                    { id: "b2", label: "B2" },
                    { id: "b3", label: "B3" }
                ]
            },
            {
                id: "change_waypoint",
                label: "Change Waypoint",
                subOptions: [
                    { id: "wp1", label: "WP 1" },
                    { id: "wp2", label: "WP 2" },
                    { id: "wp3", label: "WP 3" }
                ]
            },
            {
                id: "action_3",
                label: "Action 3",
                subOptions: [
                    { id: "opt_a", label: "Option A" },
                    { id: "opt_b", label: "Option B" }
                ]
            },
            {
                id: "action_4",
                label: "Action 4",
                subOptions: [
                    { id: "mode_1", label: "Mode 1" },
                    { id: "mode_2", label: "Mode 2" }
                ]
            }
        ]

        onSelectionCommitted: function(selections) {
            console.log("Committed selections:", JSON.stringify(selections));
        }
    }
}