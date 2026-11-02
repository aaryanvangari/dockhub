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

namespace {
constexpr int RequestTimeoutMs = 10000;
constexpr qsizetype MaxResponseBytes = 64 * 1024 * 1024;

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

QVariantMap failure(const QString &message, int status = 0)
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

// Returns true only when a complete HTTP response body is present.
bool responseComplete(const QByteArray &buffer, qsizetype headerEnd,
                      const QList<QByteArray> &headers, qsizetype contentLength,
                      bool chunked)
{
    const QByteArray body = buffer.mid(headerEnd + 4);
    if (chunked) {
        // A terminating zero-sized chunk, optionally followed by trailers.
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
                // Empty trailer section or a trailer block ending in CRLF CRLF.
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
    return false; // Without framing, wait for the server to close the connection.
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

QVariantMap parseHttpResponse(const QByteArray &response)
{
    const qsizetype headerEnd = response.indexOf("\r\n\r\n");
    if (headerEnd < 0)
        return failure(QStringLiteral("Invalid HTTP response: headers are incomplete"));

    const QList<QByteArray> lines = response.left(headerEnd).split('\n');
    if (lines.isEmpty())
        return failure(QStringLiteral("Invalid HTTP response: missing status line"));

    static const QRegularExpression statusRegex(QStringLiteral("^HTTP/\\d(?:\\.\\d)?\\s+(\\d{3})(?:\\s|$)"));
    const auto statusMatch = statusRegex.match(QString::fromLatin1(lines.first().trimmed()));
    if (!statusMatch.hasMatch())
        return failure(QStringLiteral("Invalid HTTP response: malformed status line"));

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
            return failure(QStringLiteral("Invalid or incomplete chunked HTTP response"), status);
    } else {
        const QByteArray lengthHeader = headerValue(headers, "Content-Length");
        if (!lengthHeader.isEmpty()) {
            bool ok = false;
            const qulonglong length = lengthHeader.toULongLong(&ok);
            if (!ok || length > static_cast<qulonglong>(MaxResponseBytes))
                return failure(QStringLiteral("Invalid HTTP Content-Length"), status);
            if (payload.size() < static_cast<qsizetype>(length))
                return failure(QStringLiteral("Incomplete HTTP response body"), status);
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
            // Latin-1 preserves byte values for Docker's multiplexed log frames.
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
} // namespace

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
        finishImmediately(failure(QStringLiteral("Request ID must not be empty")));
        return;
    }
    if (socketPath.isEmpty() || socketPath.contains(QChar::Null)) {
        finishImmediately(failure(QStringLiteral("Invalid Docker socket path")));
        return;
    }
    if (method.isEmpty() || method.contains(QLatin1Char('\r')) || method.contains(QLatin1Char('\n')) ||
        endpoint.isEmpty() || !endpoint.startsWith(QLatin1Char('/')) ||
        endpoint.contains(QLatin1Char('\r')) || endpoint.contains(QLatin1Char('\n')) ||
        endpoint.contains(QLatin1Char(' '))) {
        finishImmediately(failure(QStringLiteral("Invalid HTTP method or endpoint")));
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
        finish(failure(QStringLiteral("Docker socket request timed out")));
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
        // qDebug().noquote() << "[DockHub Unix] Connected; queued request bytes:"
        //                    << accepted << "of" << request.size();
        if (accepted != request.size())
            finish(failure(QStringLiteral("Failed to queue the complete HTTP request")));
    });
    connect(socket, &QLocalSocket::readyRead, this,
            [socket, state, finish] {
        const QByteArray received = socket->readAll();
        state->response += received;

        // qDebug().noquote() << "[DockHub Unix] Received chunk:"
        //                    << received.size() << "bytes; accumulated:"
        //                    << state->response.size() << "bytes";
        // qDebug().noquote() << "[DockHub Unix] Raw response (hex):"
        //                    << QString::fromLatin1(state->response.toHex(' '));

        if (state->response.size() > MaxResponseBytes) {
            finish(failure(QStringLiteral("Docker response exceeded the 64 MiB limit")));
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
        // qDebug().noquote() << "[DockHub Unix] Socket disconnected; final response:"
        //                    << state->response.size() << "bytes";
        // qDebug().noquote() << "[DockHub Unix] Final response (hex):"
        //                    << QString::fromLatin1(state->response.toHex(' '));
        finish(parseHttpResponse(state->response));
    });
    connect(socket, &QLocalSocket::errorOccurred, this,
            [socket, finish](QLocalSocket::LocalSocketError error) {
        qWarning().noquote() << "[DockHub Unix] Socket error:"
                             << error << socket->errorString();
        if (error == QLocalSocket::PeerClosedError) {
            // disconnected() will parse any bytes already received.
            return;
        }
        finish(failure(socket->errorString()));
    });

    timer->start(RequestTimeoutMs);
    // qDebug().noquote() << "[DockHub Unix] Connecting to socket:" << socketPath
    //                    << "request:" << method << endpoint;
    socket->connectToServer(socketPath, QIODevice::ReadWrite);
}
