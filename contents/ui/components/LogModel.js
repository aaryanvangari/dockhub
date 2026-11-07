.pragma library

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

function createLogModel(maxEntries, emitOnNew) {
    return {
        maxEntries: maxEntries,
        emitOnNew: emitOnNew,
        entries: [],
        currentIndex: 0,
        currentFilter: "",

        // Append a new log entry at the beginning (newest-first)
        appendEntry: function (timestamp, stream, message) {
            const entry = {
                timestamp: timestamp,
                stream: stream,
                message: message,
                id: Date.now() + Math.random()
            };
            this.entries.unshift(entry);

            // Enforce the entry limit
            if (this.entries.length > this.maxEntries) {
                this.entries.pop();
            }

            // Scroll to the newest entry
            this.currentIndex = this.entries.length - 1;

            // Emit a signal when a new entry arrives
            // Note: postMessage is not available in .pragma library mode,
            // so we emit via the parent QML model instead
            if (this.emitOnNew) {
                // Signal emission handled by QML wrapper (LogModel.qml)
                // which uses onAboutToAppendChanged to propagate new entries
            }
        },

        // Clear all entries
        clear: function () {
            this.entries = [];
            this.currentIndex = 0;
        },

        // Get the stream color (used for display)
        getStreamColor: function (stream) {
            if (stream === "stdout")
                return "#4ec9b0";  // Teal/Green
            if (stream === "stderr")
                return "#e83e8c";  // Pink/Red
            return "#6c757d";     // Gray
        },

        // Format the timestamp for display
        formatTimestamp: function (timestamp) {
            if (timestamp === null)
                return "";
            const d = new Date(timestamp);
            const y = d.getFullYear();
            const M = String(d.getMonth() + 1).padStart(2, "0");
            const dStr = String(d.getDate()).padStart(2, "0");
            const h = String(d.getHours()).padStart(2, "0");
            const m = String(d.getMinutes()).padStart(2, "0");
            const s = String(d.getSeconds()).padStart(2, "0");
            return y + "-" + M + "-" + dStr + " " + h + ":" + m + ":" + s;
        },

        // Filter entries based on currentFilter
        getFilteredEntries: function () {
            const query = this.currentFilter.toLowerCase();
            if (query === "")
                return this.entries;

            const filtered = [];
            for (let i = 0; i < this.entries.length; ++i) {
                const entry = this.entries[i];
                if (entry) {
                    const text = (entry.message || "").toLowerCase();
                    if (text.indexOf(query) >= 0) {
                        filtered.push(entry);
                    }
                }
            }
            return filtered;
        }
    };
}