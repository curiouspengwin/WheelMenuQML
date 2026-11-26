import QtQuick 2.15

Item {
    id: wheelRoot
    anchors.fill: parent

    // Maximum allowed segments on the inner wheel
    readonly property int maxInnerSegments: 8

    // Model format for each primary option:
    // [{ id: "target", label: "Change Target", icon: "...", subOptions: [{ id: "all", label: "All", icon: "..." }, ...] }, ...]
    property var items: []

    // Partial arc configuration (in degrees; 0 = right, -90 = top, -180 = left)
    property real arcStartAngle: -195
    property real arcSpanAngle: 230

    // Radii around the center marker
    property real centerHitRadius: 22
    property real innerWheelInnerRadius: 48
    property real innerWheelOuterRadius: 122
    property real outerWheelInnerRadius: 128
    property real outerWheelOuterRadius: 202

    // Parallel gap between adjacent segments
    property real segmentGap: 7

    // Hover delay (ms) before opening the secondary wheel for a hovered primary option
    property int hoverOpenDelay: 120

    // Menu open state & currently open secondary menu's primary index (-1 if none)
    property bool menuOpen: false
    // The single inner segment currently chosen (-1 if none)
    property int chosenPrimaryIndex: -1
    property int activePrimaryIndex: -1
    property int hoveredPrimaryIndex: -1
    property int hoveredSecondaryIndex: -1

    // Map of primaryId -> array/object of selected subOption ids
    // e.g. { "target": ["all", "current"] }
    property var selectedByPrimary: ({})

    property bool clearOnCommit: true

    signal selectionReset()

    signal menuOpened()
    signal menuClosed()
    signal primaryHovered(int index, var primaryItem)
    signal secondaryToggled(int primaryIndex, var subOption, bool isSelected)
    signal selectionCommitted(var selectionsByPrimary)

    // Clamp inner items to max 8
    readonly property var effectiveItems: {
        if (!items || items.length === 0)
            return [];
        return items.slice(0, maxInnerSegments);
    }

    function _primaryKey(idx) {
        if (idx < 0 || idx >= effectiveItems.length)
            return "";
        var p = effectiveItems[idx];
        return p.id !== undefined ? p.id : idx;
    }

    // Makes `primaryIndex` the sole chosen inner segment and clears selections
    // associated with any previously chosen inner segment.
    function choosePrimarySegment(primaryIndex) {
        if (primaryIndex < 0 || primaryIndex >= effectiveItems.length)
            return;

        if (chosenPrimaryIndex !== -1 && chosenPrimaryIndex !== primaryIndex) {
            var prevKey = _primaryKey(chosenPrimaryIndex);
            var copy = JSON.parse(JSON.stringify(selectedByPrimary));
            if (copy[prevKey] !== undefined) {
                delete copy[prevKey];
                selectedByPrimary = copy;
            }
        }

        chosenPrimaryIndex = primaryIndex;
    }

    function openMenu() {
        if (!menuOpen) {
            menuOpen = true;
            activePrimaryIndex = -1;
            hoveredPrimaryIndex = -1;
            hoveredSecondaryIndex = -1;
            menuOpened();
        }
    }

    function closeAndCommit() {
        if (menuOpen) {
            hoverTimer.stop();
            var snapshot = JSON.parse(JSON.stringify(selectedByPrimary));
            menuOpen = false;
            activePrimaryIndex = -1;
            hoveredPrimaryIndex = -1;
            hoveredSecondaryIndex = -1;

            if (clearOnCommit) {
                chosenPrimaryIndex = -1;
                selectedByPrimary = {};
                selectionReset();
            }

            menuClosed();
            selectionCommitted(snapshot);
        }
    }

    function toggleMenu() {
        if (menuOpen)
            closeAndCommit();
        else
            openMenu();
    }

    function isSubOptionSelected(primaryId, subId) {
        var list = selectedByPrimary[primaryId];
        if (!list)
            return false;
        return list.indexOf(subId) !== -1;
    }

    function toggleSubOption(primaryIndex, subOption) {
        if (primaryIndex < 0 || primaryIndex >= effectiveItems.length || !subOption)
            return;

        // Claim this inner segment exclusively and clear any prior chosen segment's selections
        choosePrimarySegment(primaryIndex);

        var primaryId = _primaryKey(primaryIndex);
        var subId = subOption.id !== undefined ? subOption.id : subOption.label;

        var copy = JSON.parse(JSON.stringify(selectedByPrimary));
        var list = copy[primaryId] ? copy[primaryId].slice() : [];
        var idx = list.indexOf(subId);
        var nowSelected = false;

        if (idx === -1) {
            list.push(subId);
            nowSelected = true;
        } else {
            list.splice(idx, 1);
            nowSelected = false;
        }

        if (list.length > 0)
            copy[primaryId] = list;
        else
            delete copy[primaryId];

        selectedByPrimary = copy;
        secondaryToggled(primaryIndex, subOption, nowSelected);
    }

    function clearSelections() {
        selectedByPrimary = {};
    }

    // Computes angle range for segment i out of count segments across arcSpanAngle
    function _segmentAngles(index, count, startDeg, spanDeg) {
        if (count <= 0)
            return { start: startDeg, end: startDeg };
        var step = spanDeg / count;
        var s = startDeg + index * step;
        return { start: s, end: s + step };
    }

    // Secondary wheel fans out around the hovered/active primary segment's angular range
    function _secondaryArcRange(primaryIndex) {
        var count = effectiveItems.length;
        if (primaryIndex < 0 || primaryIndex >= count)
            return { start: arcStartAngle, end: arcStartAngle + arcSpanAngle };

        var primaryAngles = _segmentAngles(primaryIndex, count, arcStartAngle, arcSpanAngle);
        var subItems = effectiveItems[primaryIndex].subOptions || [];
        var subCount = subItems.length;
        if (subCount === 0)
            return { start: primaryAngles.start, end: primaryAngles.end };

        var primarySpan = primaryAngles.end - primaryAngles.start;
        // Fan out at least as wide as the primary segment (up to ~120 deg) so sub-items stay legible
        var desiredSpan = Math.max(primarySpan, Math.min(125, subCount * 28));
        var mid = (primaryAngles.start + primaryAngles.end) * 0.5;
        return {
            start: mid - desiredSpan * 0.5,
            end: mid + desiredSpan * 0.5
        };
    }

    // Timer for hover-to-open secondary menu
    Timer {
        id: hoverTimer
        interval: wheelRoot.hoverOpenDelay
        repeat: false
        onTriggered: {
            if (wheelRoot.menuOpen && wheelRoot.hoveredPrimaryIndex >= 0) {
                if (wheelRoot.activePrimaryIndex !== wheelRoot.hoveredPrimaryIndex) {
                    wheelRoot.activePrimaryIndex = wheelRoot.hoveredPrimaryIndex;
                    wheelRoot.hoveredSecondaryIndex = -1;
                    var item = wheelRoot.effectiveItems[wheelRoot.activePrimaryIndex];
                    wheelRoot.primaryHovered(wheelRoot.activePrimaryIndex, item);
                }
            }
        }
    }

    // Center position (anchored to center of this overlay; can be bound to marker coordinates)
    readonly property real cx: width * 0.5
    readonly property real cy: height * 0.5

    // Primary wheel segments
    Repeater {
        id: primaryRepeater
        model: wheelRoot.menuOpen ? wheelRoot.effectiveItems.length : 0

        delegate: RadialSegment {
            id: primarySeg
            anchors.fill: parent
            centerX: wheelRoot.cx
            centerY: wheelRoot.cy
            innerRadius: wheelRoot.innerWheelInnerRadius
            outerRadius: wheelRoot.innerWheelOuterRadius
            gapWidth: wheelRoot.segmentGap

            property var angs: wheelRoot._segmentAngles(
                                   index,
                                   wheelRoot.effectiveItems.length,
                                   wheelRoot.arcStartAngle,
                                   wheelRoot.arcSpanAngle)
            startAngle: angs.start
            endAngle: angs.end

            property var itemData: wheelRoot.effectiveItems[index]
            property string primaryId: itemData.id !== undefined ? itemData.id : index

            label: itemData.label || ""
            iconSource: itemData.icon || ""
            hovered: wheelRoot.hoveredPrimaryIndex === index
            active: wheelRoot.activePrimaryIndex === index
            // selected: {
            //     var sel = wheelRoot.selectedByPrimary[primaryId];
            //     return sel !== undefined && sel.length > 0;
            // }
            selected: wheelRoot.chosenPrimaryIndex === index
        }
    }

    // Secondary wheel segments (only for the currently active primary segment)
    readonly property var activeSubOptions: {
        if (!menuOpen || activePrimaryIndex < 0 || activePrimaryIndex >= effectiveItems.length)
            return [];
        return effectiveItems[activePrimaryIndex].subOptions || [];
    }

    readonly property var activeSecondaryArc: _secondaryArcRange(activePrimaryIndex)

    Repeater {
        id: secondaryRepeater
        model: wheelRoot.activeSubOptions.length

        delegate: RadialSegment {
            id: secondarySeg
            anchors.fill: parent
            centerX: wheelRoot.cx
            centerY: wheelRoot.cy
            innerRadius: wheelRoot.outerWheelInnerRadius
            outerRadius: wheelRoot.outerWheelOuterRadius
            gapWidth: wheelRoot.segmentGap

            property var angs: wheelRoot._segmentAngles(
                                   index,
                                   wheelRoot.activeSubOptions.length,
                                   wheelRoot.activeSecondaryArc.start,
                                   wheelRoot.activeSecondaryArc.end - wheelRoot.activeSecondaryArc.start)
            startAngle: angs.start
            endAngle: angs.end

            property var subData: wheelRoot.activeSubOptions[index]
            property string primaryId: {
                var p = wheelRoot.effectiveItems[wheelRoot.activePrimaryIndex];
                return p ? (p.id !== undefined ? p.id : wheelRoot.activePrimaryIndex) : "";
            }
            property string subId: subData.id !== undefined ? subData.id : subData.label

            label: subData.label || ""
            iconSource: subData.icon || ""
            hovered: wheelRoot.hoveredSecondaryIndex === index
            selected: wheelRoot.isSubOptionSelected(primaryId, subId)
        }
    }

    // Temporary center marker visual (replace or hide when attaching to an existing marker)
    Rectangle {
        id: tempCenterMarker
        x: wheelRoot.cx - width * 0.5
        y: wheelRoot.cy - height * 0.5
        width: wheelRoot.centerHitRadius * 2
        height: wheelRoot.centerHitRadius * 2
        radius: width * 0.5
        color: wheelRoot.menuOpen ? "#38bdf8" : "#e2e8f0"
        border.color: "#0f172a"
        border.width: 2

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: "#0f172a"
        }
    }

    // Pointer tracking & hit-testing across center marker, primary ring, secondary ring, and outside
    MouseArea {
        id: pointerArea
        anchors.fill: parent
        hoverEnabled: true

        function _hitTestPrimary(px, py) {
            for (var i = 0; i < primaryRepeater.count; ++i) {
                var seg = primaryRepeater.itemAt(i);
                if (seg && seg.containsPoint(px, py))
                    return i;
            }
            return -1;
        }

        function _hitTestSecondary(px, py) {
            for (var i = 0; i < secondaryRepeater.count; ++i) {
                var seg = secondaryRepeater.itemAt(i);
                if (seg && seg.containsPoint(px, py))
                    return i;
            }
            return -1;
        }

        function _isInCenter(px, py) {
            var dx = px - wheelRoot.cx;
            var dy = py - wheelRoot.cy;
            return Math.sqrt(dx * dx + dy * dy) <= wheelRoot.centerHitRadius;
        }

        onPositionChanged: {
            if (!wheelRoot.menuOpen)
                return;

            var secHit = _hitTestSecondary(mouse.x, mouse.y);
            var priHit = _hitTestPrimary(mouse.x, mouse.y);

            wheelRoot.hoveredSecondaryIndex = secHit;

            if (priHit !== -1) {
                if (wheelRoot.hoveredPrimaryIndex !== priHit) {
                    wheelRoot.hoveredPrimaryIndex = priHit;
                    hoverTimer.restart();
                } else if (wheelRoot.activePrimaryIndex !== priHit && !hoverTimer.running) {
                    hoverTimer.restart();
                }
            } else if (secHit === -1) {
                // Pointer is neither on a primary segment nor on the secondary wheel
                wheelRoot.hoveredPrimaryIndex = -1;
                hoverTimer.stop();
            }
        }

        onClicked: {
            // 1. Center marker clicked -> open or close/commit
            if (_isInCenter(mouse.x, mouse.y)) {
                wheelRoot.toggleMenu();
                return;
            }

            if (!wheelRoot.menuOpen)
                return;

            // 2. Secondary wheel option clicked -> toggle multi-select
            var secHit = _hitTestSecondary(mouse.x, mouse.y);
            if (secHit !== -1) {
                var subOpt = wheelRoot.activeSubOptions[secHit];
                wheelRoot.toggleSubOption(wheelRoot.activePrimaryIndex, subOpt);
                return;
            }

            // 3. Primary option clicked -> open its secondary menu immediately
            var priHit = _hitTestPrimary(mouse.x, mouse.y);
            if (priHit !== -1) {
                hoverTimer.stop();
                wheelRoot.choosePrimarySegment(priHit);
                wheelRoot.hoveredPrimaryIndex = priHit;
                if (wheelRoot.activePrimaryIndex !== priHit) {
                    wheelRoot.activePrimaryIndex = priHit;
                    wheelRoot.hoveredSecondaryIndex = -1;
                    wheelRoot.primaryHovered(priHit, wheelRoot.effectiveItems[priHit]);
                }
                return;
            }

            // 4. Clicked outside the menu -> emit selected options and close
            wheelRoot.closeAndCommit();
        }
    }
}