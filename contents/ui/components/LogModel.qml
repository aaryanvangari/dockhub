pragma Library

import QtQuick

// ------------------------------------------------------------------
// LogModel
// ------------------------------------------------------------------
//
// A QML Model for Docker container logs with newest-first ordering
// and a configurable entry limit.
//
// Used by ContainerDetail to display streaming logs without
// requiring the QML view to manage history.
//

ListModel {
    id: model
    property int maxEntries: 1000
    property int currentIndex: 0
    property string currentFilter: ""

    // Append a new log entry at the beginning (newest-first)
    function appendEntry(timestamp, stream, message) {
        const entry = {
            timestamp: timestamp,
            stream: stream,
            message: message
        };
        model.append(entry);

        // Enforce the entry limit
        if (model.count > maxEntries) {
            model.remove(0);
        }

        // Scroll to the newest entry
        currentIndex = model.count - 1;
    }

    // Clear all entries
    function clear() {
        model.clear();
        currentIndex = 0;
    }

    // Get the stream color (used for display)
    function getStreamColor(stream) {
        if (stream === "stdout")
            return "#4ec9b0";  // Teal/Green
        if (stream === "stderr")
            return "#e83e8c";  // Pink/Red
        return "#6c757d";     // Gray
    }

    // Format the timestamp for display
    function formatTimestamp(timestamp) {
        if (timestamp === null)
            return "";
        const d = new Date(timestamp);
        const yyyy = d.getFullYear();
        const MM = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        const hh = String(d.getHours()).padStart(2, '0');
        const mm = String(d.getMinutes()).padStart(2, '0');
        const ss = String(d.getSeconds()).padStart(2, '0');
        return yyyy + "-" + MM + "-" + dd + " " + hh + ":" + mm + ":" + ss;
    }

    // Filter entries based on currentFilter
    function getFilteredEntries() {
        const query = currentFilter.toLowerCase();
        if (query === "")
            return model;

        const filtered = ListModel {
            count: model.count
        };

        for (let i = 0; i < model.count; ++i) {
            const entry = model.get(i);
            if (entry) {
                const text = (entry.message || "").toLowerCase();
                if (text.indexOf(query) >= 0) {
                    filtered.append(entry);
                }
            }
        }

        return filtered;
    }

    // Emit a signal when a new entry arrives (for real-time updates)
    property bool emitOnNew: true

    Connections {
        target: model
        function onAboutToAppendChanged() {
            if (!model.emitOnNew)
                return;
            const count = model.count;
            if (count > 0) {
                const newest = model.get(count - 1);
                if (newest) {
                    postMessage({
                        type: "newEntry",
                        entry: newest
                    });
                }
            }
        }
    }

    Component.onCompleted: {
        // Ensure currentIndex is valid
        if (currentIndex < 0 || currentIndex >= model.count) {
            currentIndex = Math.max(0, model.count - 1);
        }
    }
}
