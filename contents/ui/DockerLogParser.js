.pragma library

// ------------------------------------------------------------------
// Docker Log Parser
// ------------------------------------------------------------------
//
// Incremental parser for Docker container logs. Supports both
// multiplexed (non-TTY) and plain-text (TTY) log formats.
//
// Multiplexed format uses 8-byte headers:
//   - Bytes 0-1: Reserved (0-2 indicates multiplexed)
//   - Bytes 2-3: Stream type (1=stdout, 2=stderr)
//   - Bytes 4-7: Payload length (big-endian)
//
// TTY output is plain UTF-8 text.
//

// ------------------------------------------------------------------
// Log entry structure
// ------------------------------------------------------------------

// A complete log entry with parsed data
function createLogEntry(timestamp, stream, message) {
    return {
        timestamp: timestamp,
        stream: stream,   // "stdout" or "stderr"
        message: message  // Plain text message
    };
}

// ------------------------------------------------------------------
// Line buffering and frame assembly
// ------------------------------------------------------------------

// Accumulates incomplete lines across chunks, yielding complete lines
// when a newline is received or when a frame boundary is reached.
function parseLines(input, currentLineBuffer, frameState) {
    var output = [];

    // Frame state: { bytes: [], position: number, stream: string }
    // Tracks incomplete multiplexed frames across chunks.

    var offset = 0;
    while (offset < input.length) {
        var byte = input.charCodeAt(offset);

        // Check for frame header start (first byte 0-2)
        if (byte <= 2 && frameState.bytes.length === 0) {
            // Save any incomplete line before processing frame
            if (currentLineBuffer.length > 0) {
                output.push({
                    line: currentLineBuffer,
                    frameState: frameState
                });
                currentLineBuffer = "";
            }

            // Read 8-byte multiplexed header
            if (offset + 8 > input.length) {
                // Frame header is incomplete; save for next chunk
                frameState = {
                    bytes: input.slice(offset),
                    position: offset + 8,
                    stream: null
                };
                break;
            }

            var length = input.charCodeAt(offset + 4) * 16777216 +
                         input.charCodeAt(offset + 5) * 65536 +
                         input.charCodeAt(offset + 6) * 256 +
                         input.charCodeAt(offset + 7);

            var streamType = input.charCodeAt(offset + 2);
            var stream = (streamType === 1) ? "stdout" :
                         (streamType === 2) ? "stderr" : null;

            if (length === 0) {
                // Empty frame - just a newline in the stream
                output.push(createLogEntry(null, stream || "unknown", "\n"));
                offset += 8;
                continue;
            }

            // Save any incomplete line before the frame
            if (currentLineBuffer.length > 0) {
                output.push({
                    line: currentLineBuffer,
                    frameState: {
                        bytes: input.slice(offset + 8),
                        position: offset + 8 + length,
                        stream: stream
                    }
                });
                currentLineBuffer = "";
            }

            // Check if we have enough data for the full frame
            if (offset + 8 + length > input.length) {
                // Frame payload is incomplete; save for next chunk
                frameState = {
                    bytes: input.slice(offset + 8),
                    position: offset + 8 + length,
                    stream: stream
                };
                break;
            }

            // Extract the frame payload
            var payload = input.slice(offset + 8, offset + 8 + length);

            // Parse the payload into lines
            var lines = payload.split(/\r?\n/);
            var lastLine = lines.pop();

            for (var i = 0; i < lines.length; ++i) {
                var line = lines[i];
                if (line.length > 0) {
                    output.push(createLogEntry(null, stream || "unknown", line));
                }
            }

            // If the last line doesn't end with newline, buffer it
            if (lastLine.length > 0) {
                currentLineBuffer = lastLine;
            }

            offset += 8 + length;
            continue;
        }

        // Normal text character - append to current line buffer
        currentLineBuffer += String.fromCharCode(byte);

        // Check for line break
        if (currentLineBuffer.lastIndexOf('\n') >= 0 ||
            currentLineBuffer.lastIndexOf('\r') >= 0) {
            var line = currentLineBuffer.slice(0, -1);
            if (line.length > 0) {
                output.push(createLogEntry(null, frameState.stream || "unknown", line));
            }
            currentLineBuffer = currentLineBuffer.slice(-1);
        }

        ++offset;
    }

    // Return remaining buffer and frame state
    return {
        output: output,
        currentLineBuffer: currentLineBuffer,
        frameState: frameState
    };
}

// ------------------------------------------------------------------
// TTY output handling
// ------------------------------------------------------------------

// TTY output is plain UTF-8 text, but may contain ANSI escape codes
// for colors and formatting. We decode these but don't strip them
// to preserve the original formatting for display.
function decodeTTYPayload(payload) {
    // TTY output is already plain UTF-8; no decoding needed here.
    // The payload arrives as-is from Docker.
    return payload;
}

// ------------------------------------------------------------------
// Public API
// ------------------------------------------------------------------

// Parses a chunk of incoming log data, returning complete log entries.
//
// Returns:
//   - entries: Array of complete log entries
//   - pendingLine: String buffer for incomplete final line
//   - pendingFrame: Object containing incomplete frame state, or null
function parseLogChunk(chunk, pendingLine, pendingFrame) {
    var result = parseLines(chunk, pendingLine, pendingFrame);
    return {
        entries: result.output,
        pendingLine: result.currentLineBuffer,
        pendingFrame: result.frameState
    };
}

// ------------------------------------------------------------------
// Entry point for incremental parsing
// ------------------------------------------------------------------

// Main parsing function used by the streaming API
function parseLogData(data, pendingLine, pendingFrame) {
    var result = parseLines(data, pendingLine, pendingFrame);
    return {
        entries: result.output,
        pendingLine: result.currentLineBuffer,
        pendingFrame: result.frameState
    };
}
