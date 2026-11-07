.pragma library

// ------------------------------------------------------------------
// Docker log multiplexing parser
// ------------------------------------------------------------------

/*
 * Docker non-TTY log streams use 8-byte headers:
 *
 *   Byte 0:    stream type (0 = stdin, 1 = stdout, 2 = stderr)
 *   Bytes 1-3: reserved (zero)
 *   Bytes 4-7: payload length, unsigned big-endian integer
 *
 * The parser receives decoded HTTP response-body data from
 * UnixSocketBridge. HTTP chunk framing has already been removed.
 *
 * It handles:
 *   - Headers split across multiple incoming chunks.
 *   - Payloads split across multiple incoming chunks.
 *   - Multiple frames in a single incoming chunk.
 *   - TTY/plain-text log streams.
 *   - UTF-8 text split across incoming chunks.
 */

// ------------------------------------------------------------------
// Parser creation
// ------------------------------------------------------------------

function createParser() {
    return {
        buffer: "",
        mode: "detect",
        finished: false,
        maxFrameSize: 64 * 1024 * 1024
    };
}

// ------------------------------------------------------------------
// Convert incoming data to a byte-preserving JavaScript string
// ------------------------------------------------------------------

function toBinaryString(data) {
    if (data === null || data === undefined)
        return "";

    if (typeof data === "string")
        return data;

    // QByteArray values exposed to QML may provide toString().
    if (typeof data.toString === "function")
        return data.toString();

    return String(data);
}

// ------------------------------------------------------------------
// Convert UTF-8 bytes to JavaScript text
// ------------------------------------------------------------------

function decodeUtf8(binary) {
    if (!binary)
        return "";

    try {
        // Convert the byte-preserving string into UTF-8 text.
        return decodeURIComponent(escape(binary));
    } catch (error) {
        // Preserve the content if the payload contains invalid UTF-8.
        return binary;
    }
}

// ------------------------------------------------------------------
// Check Docker multiplex header
// ------------------------------------------------------------------

function hasDockerHeader(buffer, offset) {
    if (buffer.length - offset < 8)
        return false;

    const streamType = buffer.charCodeAt(offset);

    if (streamType > 2)
        return false;

    if (buffer.charCodeAt(offset + 1) !== 0 ||
        buffer.charCodeAt(offset + 2) !== 0 ||
        buffer.charCodeAt(offset + 3) !== 0) {
        return false;
    }

    return true;
}

// ------------------------------------------------------------------
// Read Docker frame payload length
// ------------------------------------------------------------------

function readFrameLength(buffer, offset) {
    return buffer.charCodeAt(offset + 4) * 16777216 +
           buffer.charCodeAt(offset + 5) * 65536 +
           buffer.charCodeAt(offset + 6) * 256 +
           buffer.charCodeAt(offset + 7);
}

// ------------------------------------------------------------------
// Emit plain-text data
// ------------------------------------------------------------------

function emitPlain(parser, callback) {
    if (!parser.buffer.length)
        return;

    const data = decodeUtf8(parser.buffer);

    parser.buffer = "";

    if (data.length)
        callback("stdout", data);
}

// ------------------------------------------------------------------
// Push incoming data into the parser
// ------------------------------------------------------------------

function push(parser, incomingData, callback) {
    if (!parser || parser.finished || !callback)
        return;

    const incoming = toBinaryString(incomingData);

    if (!incoming.length)
        return;

    parser.buffer += incoming;

    // --------------------------------------------------------------
    // Detect whether this is a multiplexed Docker stream or TTY text.
    // --------------------------------------------------------------

    if (parser.mode === "detect") {
        if (parser.buffer.length < 8)
            return;

        if (hasDockerHeader(parser.buffer, 0)) {
            parser.mode = "multiplexed";
        } else {
            parser.mode = "plain";
            emitPlain(parser, callback);
            return;
        }
    }

    // --------------------------------------------------------------
    // Plain TTY output.
    // --------------------------------------------------------------

    if (parser.mode === "plain") {
        emitPlain(parser, callback);
        return;
    }

    // --------------------------------------------------------------
    // Multiplexed Docker frames.
    // --------------------------------------------------------------

    while (parser.mode === "multiplexed") {
        if (parser.buffer.length < 8)
            return;

        if (!hasDockerHeader(parser.buffer, 0)) {
            // The stream no longer looks like a valid Docker frame.
            // Preserve remaining data rather than silently discarding it.
            parser.mode = "plain";
            emitPlain(parser, callback);
            return;
        }

        const streamType = parser.buffer.charCodeAt(0);
        const payloadLength = readFrameLength(parser.buffer, 0);

        if (payloadLength > parser.maxFrameSize) {
            parser.mode = "plain";
            emitPlain(parser, callback);
            return;
        }

        if (parser.buffer.length < 8 + payloadLength)
            return;

        const payload =
            parser.buffer.substring(8, 8 + payloadLength);

        parser.buffer =
            parser.buffer.substring(8 + payloadLength);

        if (payload.length) {
            const stream =
                streamType === 2 ? "stderr" : "stdout";

            callback(stream, decodeUtf8(payload));
        }

        if (!parser.buffer.length)
            return;
    }
}

// ------------------------------------------------------------------
// Finish parser
// ------------------------------------------------------------------

function finish(parser, callback) {
    if (!parser || parser.finished)
        return;

    parser.finished = true;

    if (!parser.buffer.length)
        return;

    // A complete Docker frame should have been consumed by push().
    // Any remaining bytes are preserved as plain output.
    emitPlain(parser, callback);
}

// ------------------------------------------------------------------
// Decode a complete one-shot Docker log response
// ------------------------------------------------------------------

function decodeComplete(input) {
    if (input === null || input === undefined)
        return "";

    const parser = createParser();
    let output = "";

    push(parser, input, function(stream, data) {
        output += data;
    });

    finish(parser, function(stream, data) {
        output += data;
    });

    return output;
}
