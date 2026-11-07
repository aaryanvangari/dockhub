#include "UnixSocketBridge.h"

#include <QLocalSocket>
#include <QTimer>
#include <QPointer>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QJsonValue>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>
#include <QByteArray>
#include <QUrl>
#include <QtGlobal>
#include <QSharedPointer>
#include <QDebug>

// ------------------------------------------------------------------
// Forward declarations for helpers (defined later in this namespace)
// ------------------------------------------------------------------
constexpr int RequestTimeoutMs = 10000;
constexpr qsizetype MaxResponseBytes = 64 * 1024 * 1024;

// Forward declarations
QVariantMap streamingFailure(const QString &message, int status = 0);
QByteArray headerValue(const QList<QByteArray> &headers, const QByteArray &name);
bool responseComplete(const QByteArray &buffer, qsizetype headerEnd,
                       const QList<QByteArray> &headers, qsizetype contentLength,
                       bool chunked);
QVariantMap parseHttpResponse(const QByteArray &response);
QVariant jsonValueToVariant(const QJsonValue &value);
QByteArray decodeChunkedBody(const QByteArray &body, bool *ok);

// ------------------------------------------------------------------
// Streaming helpers
// ------------------------------------------------------------------

QVariantMap streamingFailure(const QString &message, int status)
{
    return {{QStringLiteral("success"), false},
            {QStringLiteral("status"), status},
            {QStringLiteral("data"), QVariant()},
            {QStringLiteral("error"), message}};
}

QByteArray headerValue(const QList<QByteArray> &headers, const QByteArray &name)
{
    for (const QByteArray &line : headers) {
        const qsizetype colon = line.indexOf(':');
        if (colon > 0 && line.left(colon).trimmed().compare(name, Qt::CaseInsensitive) == 0)
            return line.mid(colon + 1).trimmed();
    }
    return {};
}

bool responseComplete(const QByteArray &buffer, qsizetype headerEnd,
                       const QList<QByteArray> &headers, qsizetype contentLength,
                       bool chunked)
{
    const QByteArray body = buffer.mid(headerEnd + 4);
    if (chunked) {
        qsizetype pos = 0;
        while (true) {
            const qsizetype lineEnd = body.indexOf("\r\n", pos);
            if (lineEnd < 0)
                return false;
            QByteArray sizeLine = body.mid(pos, lineEnd - pos);
            const qsizetype extension = sizeLine.indexOf(';');
            if (extension >= 0)
                sizeLine.truncate(extension);
            bool ok = false;
            const qulonglong size = sizeLine.trimmed().toULongLong(&ok, 16);
            if (!ok)
                return false;
            pos = lineEnd + 2;
            if (size == 0) {
                if (body.size() >= pos + 2 && body.mid(pos, 2) == "\r\n")
                    return true;
                return body.indexOf("\r\n\r\n", pos) >= 0;
            }
            if (size > static_cast<qulonglong>(body.size() - pos - 2))
                return false;
            pos += static_cast<qsizetype>(size);
            if (body.mid(pos, 2) != "\r\n")
                return false;
            pos += 2;
        }
    }
    if (contentLength >= 0)
        return body.size() >= contentLength;
    Q_UNUSED(headers);
    return false;
}

QVariantMap parseHttpResponse(const QByteArray &response)
{
    const qsizetype headerEnd = response.indexOf("\r\n\r\n");
    if (headerEnd < 0)
        return streamingFailure(QStringLiteral("Invalid HTTP response: headers are incomplete"));

    const QList<QByteArray> lines = response.left(headerEnd).split('\n');
    if (lines.isEmpty())
        return streamingFailure(QStringLiteral("Invalid HTTP response: missing status line"));

    static const QRegularExpression statusRegex(QStringLiteral("^HTTP/\\d(?:\\.\\d)?\\s+(\\d{3})(?:\\s|$)"));
    const auto statusMatch = statusRegex.match(QString::fromLatin1(lines.first().trimmed()));
    if (!statusMatch.hasMatch())
        return streamingFailure(QStringLiteral("Invalid HTTP response: malformed status line"));

    const int status = statusMatch.captured(1).toInt();
    QList<QByteArray> headers;
    for (qsizetype i = 1; i < lines.size(); ++i)
        headers.append(lines.at(i).trimmed());

    QByteArray payload = response.mid(headerEnd + 4);
    const QByteArray transferEncoding = headerValue(headers, "Transfer-Encoding").toLower();
    const bool chunked = transferEncoding.split(',').contains(QByteArrayLiteral("chunked"));
    if (chunked) {
        bool ok = false;
        payload = decodeChunkedBody(payload, &ok);
        if (!ok)
            return streamingFailure(QStringLiteral("Invalid or incomplete chunked HTTP response"), status);
    } else {
        const QByteArray lengthHeader = headerValue(headers, "Content-Length");
        if (!lengthHeader.isEmpty()) {
            bool ok = false;
            const qulonglong length = lengthHeader.toULongLong(&ok);
            if (!ok || length > static_cast<qulonglong>(MaxResponseBytes))
                return streamingFailure(QStringLiteral("Invalid HTTP Content-Length"), status);
            if (payload.size() < static_cast<qsizetype>(length))
                return streamingFailure(QStringLiteral("Incomplete HTTP response body"), status);
            payload.truncate(static_cast<qsizetype>(length));
        }
    }

    QVariant data;
    if (!payload.isEmpty()) {
        QJsonParseError jsonError;
        const QJsonDocument document = QJsonDocument::fromJson(payload, &jsonError);
        if (jsonError.error == QJsonParseError::NoError && !document.isNull()) {
            if (document.isObject())
                data = jsonValueToVariant(document.object());
            else if (document.isArray())
                data = jsonValueToVariant(document.array());
            else
                data = QString::fromUtf8(payload);
        } else {
            data = QString::fromLatin1(payload);
        }
    }

    const bool success = status >= 200 && status < 300;
    QString error;
    if (!success) {
        error = QStringLiteral("HTTP %1").arg(status);
        if (data.metaType().id() == QMetaType::QVariantMap) {
            const QVariantMap map = data.toMap();
            const QString message = map.value(QStringLiteral("message")).toString();
            if (!message.isEmpty())
                error = message;
        }
    }
    return {{QStringLiteral("success"), success},
            {QStringLiteral("status"), status},
            {QStringLiteral("data"), data},
            {QStringLiteral("error"), error}};
}

QVariant jsonValueToVariant(const QJsonValue &value)
{
    switch (value.type()) {
    case QJsonValue::Null:
    case QJsonValue::Undefined:
        return {};
    case QJsonValue::Bool:
        return value.toBool();
    case QJsonValue::Double:
        return value.toDouble();
    case QJsonValue::String:
        return value.toString();
    case QJsonValue::Array: {
        QVariantList list;
        const auto array = value.toArray();
        list.reserve(array.size());
        for (const auto &item : array)
            list.append(jsonValueToVariant(item));
        return list;
    }
    case QJsonValue::Object: {
        QVariantMap map;
        const auto object = value.toObject();
        for (auto it = object.begin(); it != object.end(); ++it)
            map.insert(it.key(), jsonValueToVariant(it.value()));
        return map;
    }
    }
    return {};
}

QByteArray decodeChunkedBody(const QByteArray &body, bool *ok)
{
    QByteArray decoded;
    qsizetype pos = 0;
    *ok = false;
    while (true) {
        const qsizetype lineEnd = body.indexOf("\r\n", pos);
        if (lineEnd < 0)
            return {};
        QByteArray sizeLine = body.mid(pos, lineEnd - pos);
        const qsizetype extension = sizeLine.indexOf(';');
        if (extension >= 0)
            sizeLine.truncate(extension);
        bool parsed = false;
        const qulonglong size = sizeLine.trimmed().toULongLong(&parsed, 16);
        if (!parsed || size > static_cast<qulonglong>(MaxResponseBytes))
            return {};
        pos = lineEnd + 2;
        if (size == 0) {
            if (body.mid(pos, 2) == "\r\n") {
                *ok = true;
                return decoded;
            }
            const qsizetype trailerEnd = body.indexOf("\r\n\r\n", pos);
            if (trailerEnd >= 0) {
                *ok = true;
                return decoded;
            }
            return {};
        }
        if (size > static_cast<qulonglong>(body.size() - pos - 2))
            return {};
        decoded.append(body.constData() + pos, static_cast<qsizetype>(size));
        pos += static_cast<qsizetype>(size);
        if (body.mid(pos, 2) != "\r\n")
            return {};
        pos += 2;
    }
}

UnixSocketBridge::UnixSocketBridge(QObject *parent)
    : QObject(parent)
{
}

void UnixSocketBridge::sendHttpRequest(const QString &socketPath,
                                       const QString &method,
                                       const QString &endpoint,
                                       const QVariant &body,
                                       const QString &requestId)
{
    auto finishImmediately = [this, &requestId](const QVariantMap &result) {
        QMetaObject::invokeMethod(this, [this, requestId, result] {
            emit requestFinished(requestId, result);
        }, Qt::QueuedConnection);
    };

    if (requestId.isEmpty()) {
        finishImmediately(streamingFailure(QStringLiteral("Request ID must not be empty")));
        return;
    }
    if (socketPath.isEmpty() || socketPath.contains(QChar::Null)) {
        finishImmediately(streamingFailure(QStringLiteral("Invalid Docker socket path")));
        return;
    }
    if (method.isEmpty() || method.contains(QLatin1Char('\r')) || method.contains(QLatin1Char('\n')) ||
        endpoint.isEmpty() || !endpoint.startsWith(QLatin1Char('/')) ||
        endpoint.contains(QLatin1Char('\r')) || endpoint.contains(QLatin1Char('\n')) ||
        endpoint.contains(QLatin1Char(' '))) {
        finishImmediately(streamingFailure(QStringLiteral("Invalid HTTP method or endpoint")));
        return;
    }

    auto *socket = new QLocalSocket(this);
    auto *timer = new QTimer(socket);
    timer->setSingleShot(true);
    struct RequestState { QByteArray response; bool completed = false; };
    const auto state = QSharedPointer<RequestState>::create();

    auto finish = [this, socket, timer, state, requestId](const QVariantMap &result) {
        if (state->completed)
            return;
        state->completed = true;
        timer->stop();
        socket->abort();
        socket->deleteLater();
        emit requestFinished(requestId, result);
    };

    connect(timer, &QTimer::timeout, this, [finish] {
        finish(streamingFailure(QStringLiteral("Docker socket request timed out")));
    });
    connect(socket, &QLocalSocket::connected, this,
            [socket, method, endpoint, body, finish] {
        QByteArray bodyBytes;
        const bool hasBody = body.isValid() && !body.isNull();
        if (hasBody)
            bodyBytes = body.toString().toUtf8();

        QByteArray request;
        request += method.toLatin1() + ' ' + endpoint.toUtf8() + " HTTP/1.1\r\n";
        request += "Host: localhost\r\n";
        request += "Accept: application/json\r\n";
        request += "Connection: close\r\n";
        if (hasBody)
            request += "Content-Type: application/json\r\n";
        request += "Content-Length: " + QByteArray::number(bodyBytes.size()) + "\r\n\r\n";
        request += bodyBytes;
        const qint64 accepted = socket->write(request);
        if (accepted != request.size())
            finish(streamingFailure(QStringLiteral("Failed to queue the complete HTTP request")));
    });
    connect(socket, &QLocalSocket::readyRead, this,
            [socket, state, finish] {
        const QByteArray received = socket->readAll();
        state->response += received;

        if (state->response.size() > MaxResponseBytes) {
            finish(streamingFailure(QStringLiteral("Docker response exceeded the 64 MiB limit")));
            return;
        }
        const qsizetype headerEnd = state->response.indexOf("\r\n\r\n");
        if (headerEnd < 0)
            return;
        const QList<QByteArray> lines = state->response.left(headerEnd).split('\n');
        bool chunked = false;
        qsizetype contentLength = -1;
        for (qsizetype i = 1; i < lines.size(); ++i) {
            const QByteArray line = lines.at(i).trimmed();
            const qsizetype colon = line.indexOf(':');
            if (colon <= 0)
                continue;
            const QByteArray name = line.left(colon).trimmed();
            const QByteArray value = line.mid(colon + 1).trimmed();
            if (name.compare("Transfer-Encoding", Qt::CaseInsensitive) == 0 &&
                value.toLower().split(',').contains(QByteArrayLiteral("chunked")))
                chunked = true;
            if (name.compare("Content-Length", Qt::CaseInsensitive) == 0) {
                bool ok = false;
                const qulonglong length = value.toULongLong(&ok);
                if (ok && length <= static_cast<qulonglong>(MaxResponseBytes))
                    contentLength = static_cast<qsizetype>(length);
            }
        }
        if (responseComplete(state->response, headerEnd, lines, contentLength, chunked))
            finish(parseHttpResponse(state->response));
    });
    connect(socket, &QLocalSocket::disconnected, this, [state, finish] {
        finish(parseHttpResponse(state->response));
    });
    connect(socket, &QLocalSocket::errorOccurred, this,
            [socket, finish](QLocalSocket::LocalSocketError error) {
        qWarning().noquote() << "[DockHub Unix] Socket error:"
                              << error << socket->errorString();
        if (error == QLocalSocket::PeerClosedError) {
            return;
        }
        finish(streamingFailure(socket->errorString()));
    });

    timer->start(RequestTimeoutMs);
    socket->connectToServer(socketPath, QIODevice::ReadWrite);
}

QString UnixSocketBridge::startStreamingRequest(const QString &socketPath,
                                                const QString &method,
                                                const QString &endpoint,
                                                const QVariant &body,
                                                const QString &requestId)
{
    if (requestId.isEmpty()) {
        emit streamingFinished(requestId, streamingFailure(QStringLiteral("Request ID must not be empty")));
        return QString();
    }
    if (socketPath.isEmpty() || socketPath.contains(QChar::Null)) {
        emit streamingFinished(requestId, streamingFailure(QStringLiteral("Invalid Docker socket path")));
        return QString();
    }
    if (method.isEmpty() || method.contains(QLatin1Char('\r')) || method.contains(QLatin1Char('\n')) ||
        endpoint.isEmpty() || !endpoint.startsWith(QLatin1Char('/')) ||
        endpoint.contains(QLatin1Char('\r')) || endpoint.contains(QLatin1Char('\n')) ||
        endpoint.contains(QLatin1Char(' '))) {
        emit streamingFinished(requestId, streamingFailure(QStringLiteral("Invalid HTTP method or endpoint")));
        return QString();
    }

    // Clean up any existing state with the same requestId
    auto *existingState = m_activeStreamingRequests.value(requestId);
    if (existingState) {
        existingState->finished = true;
        existingState->stop();
        existingState->socket->abort();
        existingState->socket->deleteLater();
    }

    auto *socket = new QLocalSocket(this);
    m_activeStreamingRequests[requestId] = new StreamingRequestState{
        requestId, socket, nullptr, nullptr, endpoint, method,
        body.isValid() && !body.isNull() ? body.toString().toUtf8() : QByteArray(),
        QByteArray(), false, QVariantMap()
    };

    StreamingRequestState *state = m_activeStreamingRequests.value(requestId);

    auto *timeoutTimer = new QTimer(this);
    timeoutTimer->setSingleShot(true);
    timeoutTimer->start(RequestTimeoutMs);
    state->timeoutTimer = timeoutTimer;

    auto *readTimer = new QTimer(this);
    readTimer->setSingleShot(true);
    readTimer->start(50);
    state->readTimer = readTimer;

    auto finish = [this, requestId, state](const QVariantMap &result) {
        emit streamingFinished(requestId, result);
        stopStreamingRequest(requestId);
    };

    connect(socket, &QLocalSocket::errorOccurred, this, [this, requestId, state, socket, finish](QLocalSocket::LocalSocketError error) {
        qWarning().noquote() << "[DockHub Unix] Streaming socket error:" << error << socket->errorString();
        QVariantMap result = streamingFailure(socket->errorString());
        result["success"] = false;
        result["status"] = 0;
        finish(result);
    });

    connect(readTimer, &QTimer::timeout, this, [this, requestId, state, readTimer, finish] {
        auto *sock = state->socket;
        if (!sock || !sock->isOpen()) {
            finish(streamingFailure(QStringLiteral("No data received within timeout")));
            return;
        }
        const QByteArray received = sock->readAll();
        if (received.isEmpty()) {
            // Connection closed by server - this is normal for streaming when data ends
            finish({{QStringLiteral("success"), true},
                     {QStringLiteral("status"), 200},
                     {QStringLiteral("data"), QVariant()},
                     {QStringLiteral("error"), QString()}});
            return;
        }
        readTimer->start(50);
    });

    connect(socket, &QLocalSocket::readyRead, this,
            [this, requestId, state, socket, readTimer, finish] {
        const QByteArray received = socket->readAll();
        state->buffer += received;

        // Parse HTTP headers
        if (!state->headersReceived) {
            const qsizetype headerEnd = state->buffer.indexOf("\r\n\r\n");
            if (headerEnd < 0) {
                readTimer->start(50);
                return;
            }

            const QList<QByteArray> lines = state->buffer.left(headerEnd).split('\n');
            if (lines.isEmpty()) {
                readTimer->start(50);
                return;
            }

            const QByteArray statusLine = lines.first().trimmed();
            if (statusLine.isEmpty() || statusLine.length() < 6) {
                finish(streamingFailure(QStringLiteral("Invalid HTTP status line")));
                return;
            }

            const qsizetype colon = statusLine.indexOf(' ');
            if (colon < 0 || colon + 2 > static_cast<qsizetype>(statusLine.length())) {
                finish(streamingFailure(QStringLiteral("Invalid HTTP status line format")));
                return;
            }

            const int statusCode = statusLine.mid(colon + 1).toInt();

            QList<QByteArray> headers;
            for (qsizetype i = 1; i < lines.size(); ++i) {
                const QByteArray line = lines.at(i).trimmed();
                if (line.isEmpty())
                    continue;
                const qsizetype colonPos = line.indexOf(':');
                if (colonPos <= 0)
                    continue;
                const QByteArray name = line.left(colonPos).trimmed();
                const QByteArray value = line.mid(colonPos + 1).trimmed();
                headers.append(value);

                if (name.compare("Transfer-Encoding", Qt::CaseInsensitive) == 0 &&
                    value.toLower().split(',').contains(QByteArrayLiteral("chunked")))
                    state->chunked = true;
                if (name.compare("Content-Length", Qt::CaseInsensitive) == 0) {
                    bool ok = false;
                    const qulonglong length = value.toULongLong(&ok);
                    if (ok && length <= static_cast<qulonglong>(MaxResponseBytes))
                        state->contentLength = static_cast<qsizetype>(length);
                }
            }

            state->headersReceived = true;
            state->headersComplete = !state->chunked && state->contentLength >= 0;
            state->receivedLength = 0;
        }

        // Use local headerEnd for body parsing below
        qsizetype headerEnd = 0;
        if (state->headersReceived && !state->buffer.isEmpty()) {
            headerEnd = state->buffer.indexOf("\r\n\r\n");
        }

        if (state->chunked) {
            // Decode chunked body incrementally
            qsizetype pos = 0;
            while (pos < state->buffer.size()) {
                const qsizetype lineEnd = state->buffer.indexOf("\r\n", pos);
                if (lineEnd < 0)
                    break;
                QByteArray sizeLine = state->buffer.mid(pos, lineEnd - pos);
                const qsizetype extension = sizeLine.indexOf(';');
                if (extension >= 0)
                    sizeLine.truncate(extension);
                bool ok = false;
                const qulonglong size = sizeLine.trimmed().toULongLong(&ok, 16);
                if (!ok || size > static_cast<qulonglong>(MaxResponseBytes)) {
                    finish(streamingFailure(QStringLiteral("Invalid chunked size")));
                    return;
                }
                pos = lineEnd + 2;
                if (size == 0) {
                    if (state->buffer.mid(pos, 2) == "\r\n") {
                        if (headerEnd > 0)
                            emit streamingData(requestId, state->buffer.mid(0, headerEnd + 4 + pos));
                        state->buffer.clear();
                        readTimer->start(50);
                        return;
                    }
                    const qsizetype trailerEnd = state->buffer.indexOf("\r\n\r\n", pos);
                    if (trailerEnd >= 0) {
                        if (headerEnd > 0)
                            emit streamingData(requestId, state->buffer.mid(0, headerEnd + 4 + pos + trailerEnd - pos));
                        state->buffer.truncate(trailerEnd - pos);
                        readTimer->start(50);
                        return;
                    }
                    break;
                }
                if (size > static_cast<qulonglong>(state->buffer.size() - pos - 2)) {
                    break;
                }
                if (headerEnd > 0)
                    emit streamingData(requestId, state->buffer.mid(0, headerEnd + 4 + pos + static_cast<qsizetype>(size)));
                state->buffer.truncate(pos + static_cast<qsizetype>(size) + 2);
                pos += static_cast<qsizetype>(size) + 2;
            }
        } else if (state->headersComplete) {
            // Fixed length body - emit when complete
            if (state->receivedLength >= state->contentLength) {
                if (headerEnd > 0)
                    emit streamingData(requestId, state->buffer.mid(0, headerEnd + 4 + state->receivedLength));
                state->buffer.clear();
                state->headersComplete = false;
                readTimer->start(50);
                return;
            }
            state->receivedLength += static_cast<qsizetype>(received.size());
            if (state->receivedLength >= state->contentLength) {
                if (headerEnd > 0)
                    emit streamingData(requestId, state->buffer.mid(0, headerEnd + 4 + state->receivedLength));
                state->buffer.clear();
                state->headersComplete = false;
                readTimer->start(50);
                return;
            }
        } else {
            // Waiting for Content-Length or chunked encoding - buffer until headers complete
            readTimer->start(50);
        }
    });

    connect(socket, &QLocalSocket::disconnected, this, [this, requestId, state, finish] {
        state->finished = true;
        if (state->buffer.isEmpty()) {
            finish({{QStringLiteral("success"), true},
                     {QStringLiteral("status"), 200},
                     {QStringLiteral("data"), QVariant()},
                     {QStringLiteral("error"), QString()}});
        } else {
            finish(parseHttpResponse(state->buffer));
        }
    });

    connect(socket, &QLocalSocket::connected, this, [socket, method, endpoint, body, finish] {
        QByteArray bodyBytes;
        const bool hasBody = body.isValid() && !body.isNull();
        if (hasBody)
            bodyBytes = body.toString().toUtf8();

        QByteArray request;
        request += method.toLatin1() + ' ' + endpoint.toUtf8() + " HTTP/1.1\r\n";
        request += "Host: localhost\r\n";
        request += "Accept: application/json\r\n";
        request += "Connection: keep-alive\r\n";
        if (hasBody)
            request += "Content-Type: application/json\r\n";
        request += "Content-Length: " + QByteArray::number(bodyBytes.size()) + "\r\n\r\n";
        request += bodyBytes;
        const qint64 accepted = socket->write(request);
        if (accepted != request.size()) {
            finish(streamingFailure(QStringLiteral("Failed to queue the complete HTTP request")));
            return;
        }
    });

    return requestId;
}

void UnixSocketBridge::stopStreamingRequest(const QString &requestId)
{
    StreamingRequestState *state = m_activeStreamingRequests.take(requestId);
    if (!state)
        return;

    state->finished = true;
    state->stop();
    if (state->socket) {
        state->socket->abort();
        state->socket->deleteLater();
    }
    delete state;
}

// ------------------------------------------------------------------
// Member variables are now inline in the header
// ------------------------------------------------------------------

