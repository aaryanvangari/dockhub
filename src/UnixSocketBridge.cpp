#include "UnixSocketBridge.h"

#include <QByteArray>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLocalSocket>
#include <QMetaObject>
#include <QRegularExpression>
#include <QTimer>
#include <QVariantMap>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QSharedPointer>

namespace {

constexpr int ConnectionTimeoutMs = 10000;
constexpr qsizetype MaxHeaderBytes = 64 * 1024;
constexpr qsizetype MaxResponseBytes = 64 * 1024 * 1024;
constexpr qsizetype MaxErrorBodyBytes = 1024 * 1024;

QVariantMap failure(const QString &message, int status = 0) {
  return {{QStringLiteral("success"), false},
          {QStringLiteral("status"), status},
          {QStringLiteral("data"), QVariant()},
          {QStringLiteral("error"), message}};
}

QVariant jsonValueToVariant(const QJsonValue &value) {
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
    QVariantList result;
    const QJsonArray array = value.toArray();

    for (const QJsonValue &item : array)
      result.append(jsonValueToVariant(item));

    return result;
  }

  case QJsonValue::Object: {
    QVariantMap result;
    const QJsonObject object = value.toObject();

    for (auto it = object.begin(); it != object.end(); ++it)
      result.insert(it.key(), jsonValueToVariant(it.value()));

    return result;
  }
  }

  return {};
}

QByteArray headerValue(const QList<QByteArray> &headers,
                       const QByteArray &name) {
  for (const QByteArray &line : headers) {
    const qsizetype colon = line.indexOf(':');

    if (colon <= 0)
      continue;

    if (line.left(colon).trimmed().compare(name, Qt::CaseInsensitive) == 0) {
      return line.mid(colon + 1).trimmed();
    }
  }

  return {};
}

struct HttpHeaders {
  int status = 0;
  bool chunked = false;
  bool hasContentLength = false;
  qint64 contentLength = -1;
  QList<QByteArray> headers;
};

bool parseHeaders(const QByteArray &rawHeaders, HttpHeaders *result,
                  QString *error) {
  const QList<QByteArray> lines = rawHeaders.split('\n');

  if (lines.isEmpty()) {
    *error = QStringLiteral("Missing HTTP status line");
    return false;
  }

  static const QRegularExpression statusRegex(
      QStringLiteral("^HTTP/\\d(?:\\.\\d)?\\s+(\\d{3})(?:\\s|$)"));

  const QString statusLine = QString::fromLatin1(lines.first().trimmed());

  const auto match = statusRegex.match(statusLine);

  if (!match.hasMatch()) {
    *error = QStringLiteral("Invalid HTTP status line");
    return false;
  }

  result->status = match.captured(1).toInt();

  for (qsizetype i = 1; i < lines.size(); ++i) {
    const QByteArray line = lines.at(i).trimmed();

    if (line.isEmpty())
      continue;

    result->headers.append(line);
  }

  const QByteArray transferEncoding =
      headerValue(result->headers, "Transfer-Encoding").toLower();

  const QList<QByteArray> encodings = transferEncoding.split(',');

  for (const QByteArray &encoding : encodings) {
    if (encoding.trimmed() == "chunked") {
      result->chunked = true;
      break;
    }
  }

  const QByteArray lengthHeader =
      headerValue(result->headers, "Content-Length");

  if (!lengthHeader.isEmpty()) {
    bool ok = false;

    const qulonglong length = lengthHeader.toULongLong(&ok);

    if (!ok ||
        length > static_cast<qulonglong>(std::numeric_limits<qint64>::max())) {
      *error = QStringLiteral("Invalid HTTP Content-Length");
      return false;
    }

    result->hasContentLength = true;
    result->contentLength = static_cast<qint64>(length);
  }

  return true;
}

QVariantMap makeHttpResult(int status, const QByteArray &payload) {
  QVariant data;

  if (!payload.isEmpty()) {
    QJsonParseError parseError;

    const QJsonDocument document =
        QJsonDocument::fromJson(payload, &parseError);

    if (parseError.error == QJsonParseError::NoError && !document.isNull()) {

      if (document.isObject()) {
        data = jsonValueToVariant(document.object());
      } else if (document.isArray()) {
        data = jsonValueToVariant(document.array());
      } else {
        data = QString::fromUtf8(payload);
      }
    } else {
      // Preserve binary data values for Docker raw-stream responses.
      data = QString::fromLatin1(payload);
    }
  }

  const bool success = status >= 200 && status < 300;

  QString error;

  if (!success) {
    error = QStringLiteral("HTTP %1").arg(status);

    if (data.metaType().id() == QMetaType::QVariantMap) {
      const QString message =
          data.toMap().value(QStringLiteral("message")).toString();

      if (!message.isEmpty())
        error = message;
    }
  }

  return {{QStringLiteral("success"), success},
          {QStringLiteral("status"), status},
          {QStringLiteral("data"), data},
          {QStringLiteral("error"), error}};
}

bool validRequest(const QString &socketPath, const QString &method,
                  const QString &endpoint, QString *error) {
  if (socketPath.isEmpty() || socketPath.contains(QChar::Null)) {
    *error = QStringLiteral("Invalid Docker socket path");
    return false;
  }

  if (method.isEmpty() || method.contains('\r') || method.contains('\n')) {
    *error = QStringLiteral("Invalid HTTP method");
    return false;
  }

  if (endpoint.isEmpty() || !endpoint.startsWith('/') ||
      endpoint.contains('\r') || endpoint.contains('\n') ||
      endpoint.contains(' ')) {
    *error = QStringLiteral("Invalid HTTP endpoint");
    return false;
  }

  return true;
}

QByteArray makeRequest(const QString &method, const QString &endpoint,
                       const QVariant &body, bool keepAlive) {
  QByteArray bodyBytes;

  const bool hasBody = body.isValid() && !body.isNull();

  if (hasBody)
    bodyBytes = body.toString().toUtf8();

  QByteArray request;

  request += method.toLatin1();
  request += ' ';
  request += endpoint.toUtf8();
  request += " HTTP/1.1\r\n";

  request += "Host: localhost\r\n";
  request += "Accept: application/json\r\n";

  request += keepAlive ? "Connection: keep-alive\r\n" : "Connection: close\r\n";

  if (hasBody)
    request += "Content-Type: application/json\r\n";

  request += "Content-Length: ";
  request += QByteArray::number(bodyBytes.size());
  request += "\r\n\r\n";

  request += bodyBytes;

  return request;
}

QByteArray decodeChunkedBody(const QByteArray &body);

// ============================================================================
// Chunked response decoder
// ============================================================================

// This helper is used by one-shot requests.
// It returns the decoded body, excluding HTTP chunk framing.
QByteArray decodeChunkedBody(const QByteArray &body) {
  QByteArray decoded;
  qsizetype pos = 0;

  while (true) {
    const qsizetype lineEnd = body.indexOf("\r\n", pos);

    if (lineEnd < 0)
      return {};

    QByteArray sizeLine = body.mid(pos, lineEnd - pos);

    const qsizetype extension = sizeLine.indexOf(';');

    if (extension >= 0)
      sizeLine.truncate(extension);

    bool ok = false;

    const qulonglong size = sizeLine.trimmed().toULongLong(&ok, 16);

    if (!ok)
      return {};

    pos = lineEnd + 2;

    if (size == 0)
      return decoded;

    if (size > static_cast<qulonglong>(body.size() - pos - 2)) {
      return {};
    }

    decoded.append(body.constData() + pos, static_cast<qsizetype>(size));

    pos += static_cast<qsizetype>(size);

    if (body.mid(pos, 2) != "\r\n")
      return {};

    pos += 2;
  }
}

} // namespace

// ============================================================================
// Streaming request state
// ============================================================================

class StreamingRequestState final : public QObject {
public:
  explicit StreamingRequestState(const QString &id, QObject *parent = nullptr)
      : QObject(parent), requestId(id) {
    socket = new QLocalSocket(this);

    connectionTimer = new QTimer(this);
    connectionTimer->setSingleShot(true);
  }

  QString requestId;

  QLocalSocket *socket = nullptr;
  QTimer *connectionTimer = nullptr;

  QByteArray headerBuffer;
  QByteArray bodyBuffer;

  int status = 0;

  bool headersReceived = false;
  bool chunked = false;
  bool hasContentLength = false;
  bool finished = false;

  qint64 contentLength = -1;
  qint64 receivedLength = 0;

  // Chunk decoder state.
  enum ChunkState {
    ReadingChunkSize,
    ReadingChunkData,
    ReadingChunkTerminator,
    ReadingTrailers,
    ChunkStreamFinished
  };

  ChunkState chunkState = ReadingChunkSize;
  qint64 currentChunkSize = 0;

  QByteArray errorBody;
};

// ============================================================================
// UnixSocketBridge
// ============================================================================

UnixSocketBridge::UnixSocketBridge(QObject *parent)
    : QObject(parent)
    , m_networkAccessManager(new QNetworkAccessManager(this)) {}

UnixSocketBridge::~UnixSocketBridge() {
  const auto states = m_activeStreamingRequests.values();

  m_activeStreamingRequests.clear();

  for (StreamingRequestState *state : states) {
    if (!state)
      continue;

    state->finished = true;

    if (state->socket)
      state->socket->abort();

    state->deleteLater();
  }
}

// ============================================================================
// One-shot HTTP request
// ============================================================================

void UnixSocketBridge::sendHttpRequest(const QString &socketPath,
                                       const QString &method,
                                       const QString &endpoint,
                                       const QVariant &body,
                                       const QString &requestId) {
  auto finishImmediately = [this, requestId](const QVariantMap &result) {
    QMetaObject::invokeMethod(
        this,
        [this, requestId, result]() {
          emit requestFinished(requestId, result);
        },
        Qt::QueuedConnection);
  };

  if (requestId.isEmpty()) {
    finishImmediately(failure(QStringLiteral("Request ID must not be empty")));
    return;
  }

  QString validationError;

  if (!validRequest(socketPath, method, endpoint, &validationError)) {
    finishImmediately(failure(validationError));
    return;
  }

  auto *socket = new QLocalSocket(this);
  auto *timer = new QTimer(socket);

  timer->setSingleShot(true);

  struct RequestState {
    QByteArray response;
    bool finished = false;
  };

  auto *state = new RequestState;

  auto finish = [this, socket, timer, state,
                 requestId](const QVariantMap &result) {
    if (state->finished)
      return;

    state->finished = true;

    timer->stop();
    socket->abort();

    socket->deleteLater();

    emit requestFinished(requestId, result);

    delete state;
  };

  connect(timer, &QTimer::timeout, this, [finish]() {
    finish(failure(QStringLiteral("Docker socket connection timed out")));
  });

  connect(socket, &QLocalSocket::connected, this,
          [socket, timer, method, endpoint, body, finish]() {
            timer->stop();

            const QByteArray request =
                makeRequest(method, endpoint, body, false);

            const qint64 accepted = socket->write(request);

            if (accepted < 0) {
              finish(failure(QStringLiteral("Failed to write HTTP request")));
              return;
            }

            socket->flush();
          });

  connect(socket, &QLocalSocket::readyRead, this, [socket, state, finish]() {
    state->response += socket->readAll();

    if (state->response.size() > MaxResponseBytes) {
      finish(
          failure(QStringLiteral("Docker response exceeded the 64 MiB limit")));
      return;
    }

    const qsizetype headerEnd = state->response.indexOf("\r\n\r\n");

    if (headerEnd < 0) {
      if (state->response.size() > MaxHeaderBytes) {
        finish(failure(QStringLiteral("HTTP response headers are too large")));
      }
      return;
    }

    HttpHeaders headers;
    QString error;

    if (!parseHeaders(state->response.left(headerEnd), &headers, &error)) {
      finish(failure(error));
      return;
    }

    const QByteArray payload = state->response.mid(headerEnd + 4);

    if (headers.chunked) {
      // Check whether the complete chunked body has arrived.
      qsizetype pos = 0;

      while (true) {
        const qsizetype lineEnd = payload.indexOf("\r\n", pos);

        if (lineEnd < 0)
          return;

        QByteArray sizeLine = payload.mid(pos, lineEnd - pos);

        const qsizetype extension = sizeLine.indexOf(';');

        if (extension >= 0)
          sizeLine.truncate(extension);

        bool ok = false;

        const qulonglong size = sizeLine.trimmed().toULongLong(&ok, 16);

        if (!ok) {
          finish(failure(QStringLiteral("Invalid HTTP chunk size"),
                         headers.status));
          return;
        }

        pos = lineEnd + 2;

        if (size == 0) {
          if (payload.size() >= pos + 2 && payload.mid(pos, 2) == "\r\n") {
            finish(makeHttpResult(headers.status, decodeChunkedBody(payload)));
            return;
          }

          const qsizetype trailerEnd = payload.indexOf("\r\n\r\n", pos);

          if (trailerEnd >= 0) {
            finish(makeHttpResult(headers.status, decodeChunkedBody(payload)));
          }

          return;
        }

        if (size > static_cast<qulonglong>(payload.size() - pos - 2)) {
          return;
        }

        pos += static_cast<qsizetype>(size);

        if (payload.mid(pos, 2) != "\r\n") {
          finish(failure(QStringLiteral("Invalid HTTP chunk terminator"),
                         headers.status));
          return;
        }

        pos += 2;
      }
    }

    if (headers.hasContentLength) {
      if (payload.size() >= headers.contentLength) {
        finish(makeHttpResult(headers.status,
                              payload.left(headers.contentLength)));
      }
    }
  });

  connect(socket, &QLocalSocket::disconnected, this, [state, finish]() {
    const qsizetype headerEnd = state->response.indexOf("\r\n\r\n");

    if (headerEnd < 0) {
      finish(failure(
          QStringLiteral("Connection closed before HTTP headers arrived")));
      return;
    }

    HttpHeaders headers;
    QString error;

    if (!parseHeaders(state->response.left(headerEnd), &headers, &error)) {
      finish(failure(error));
      return;
    }

    const QByteArray payload = state->response.mid(headerEnd + 4);

    if (headers.chunked) {
      finish(makeHttpResult(headers.status, decodeChunkedBody(payload)));
      return;
    }

    if (headers.hasContentLength && payload.size() < headers.contentLength) {
      finish(failure(QStringLiteral("Incomplete HTTP response body"),
                     headers.status));
      return;
    }

    finish(
        makeHttpResult(headers.status, headers.hasContentLength
                                           ? payload.left(headers.contentLength)
                                           : payload));
  });

  connect(socket, &QLocalSocket::errorOccurred, this,
          [socket, finish](QLocalSocket::LocalSocketError error) {
            if (error == QLocalSocket::PeerClosedError)
              return;

            finish(failure(socket->errorString()));
          });

  timer->start(ConnectionTimeoutMs);

  socket->connectToServer(socketPath, QIODevice::ReadWrite);
}

// ============================================================================
// Start streaming request
// ============================================================================

QString UnixSocketBridge::startStreamingRequest(const QString &socketPath,
                                                const QString &method,
                                                const QString &endpoint,
                                                const QVariant &body,
                                                const QString &requestId) {
  if (requestId.isEmpty()) {
    emit streamingFinished(
        requestId, failure(QStringLiteral("Request ID must not be empty")));
    return {};
  }

  QString validationError;

  if (!validRequest(socketPath, method, endpoint, &validationError)) {

    emit streamingFinished(requestId, failure(validationError));

    return {};
  }

  // Reusing a request ID cancels the previous stream.
  stopStreamingRequest(requestId);

  auto *state = new StreamingRequestState(requestId, this);

  m_activeStreamingRequests.insert(requestId, state);

  auto finish = [this, state, requestId](const QVariantMap &result) {
    if (state->finished)
      return;

    state->finished = true;

    state->connectionTimer->stop();

    // Remove the state before emitting. A JavaScript handler
    // may call stopStreamingRequest() synchronously.
    if (m_activeStreamingRequests.value(requestId) == state)
      m_activeStreamingRequests.remove(requestId);

    state->socket->abort();

    emit streamingFinished(requestId, result);

    state->deleteLater();
  };

  connect(state->connectionTimer, &QTimer::timeout, this, [finish]() {
    finish(failure(QStringLiteral("Docker socket connection timed out")));
  });

  connect(state->socket, &QLocalSocket::connected, this,
          [state, method, endpoint, body, finish]() {
            state->connectionTimer->stop();

            const QByteArray request =
                makeRequest(method, endpoint, body, true);

            const qint64 accepted = state->socket->write(request);

            if (accepted < 0) {
              finish(failure(
                  QStringLiteral("Failed to write streaming HTTP request")));
              return;
            }

            state->socket->flush();
          });

  connect(
      state->socket, &QLocalSocket::readyRead, this,
      [this, state, requestId, finish]() {
        if (state->finished)
          return;

        QByteArray incoming = state->socket->readAll();

        if (incoming.isEmpty())
          return;

        // ------------------------------------------------------------
        // Read HTTP response headers incrementally.
        // ------------------------------------------------------------

        if (!state->headersReceived) {
          state->headerBuffer += incoming;

          const qsizetype headerEnd = state->headerBuffer.indexOf("\r\n\r\n");

          if (headerEnd < 0) {
            if (state->headerBuffer.size() > MaxHeaderBytes) {
              finish(failure(
                  QStringLiteral("HTTP response headers are too large")));
            }
            return;
          }

          HttpHeaders headers;
          QString error;

          if (!parseHeaders(state->headerBuffer.left(headerEnd), &headers,
                            &error)) {
            finish(failure(error));
            return;
          }

          state->status = headers.status;
          state->chunked = headers.chunked;
          state->hasContentLength = headers.hasContentLength;
          state->contentLength = headers.contentLength;
          state->headersReceived = true;

          // Move bytes following the HTTP headers into the body buffer.
          state->bodyBuffer = state->headerBuffer.mid(headerEnd + 4);

          state->headerBuffer.clear();
        } else {
          state->bodyBuffer += incoming;
        }

        // ------------------------------------------------------------
        // HTTP error responses.
        // ------------------------------------------------------------

        if (state->status < 200 || state->status >= 300) {
          if (state->bodyBuffer.size() > MaxErrorBodyBytes) {
            finish(failure(
                QStringLiteral("Docker returned HTTP %1").arg(state->status),
                state->status));
            return;
          }

          state->errorBody += state->bodyBuffer;
          state->bodyBuffer.clear();

          return;
        }

        // ------------------------------------------------------------
        // Chunked transfer encoding.
        // ------------------------------------------------------------

        if (state->chunked) {
          while (!state->finished) {

            if (state->chunkState == StreamingRequestState::ReadingChunkSize) {
              const qsizetype lineEnd = state->bodyBuffer.indexOf("\r\n");

              if (lineEnd < 0)
                break;

              QByteArray sizeLine = state->bodyBuffer.left(lineEnd);

              state->bodyBuffer.remove(0, lineEnd + 2);

              const qsizetype extension = sizeLine.indexOf(';');

              if (extension >= 0)
                sizeLine.truncate(extension);

              bool ok = false;

              const qulonglong size = sizeLine.trimmed().toULongLong(&ok, 16);

              if (!ok || size > static_cast<qulonglong>(MaxResponseBytes)) {
                finish(failure(QStringLiteral("Invalid HTTP chunk size"),
                               state->status));
                return;
              }

              state->currentChunkSize = static_cast<qint64>(size);

              if (size == 0) {
                state->chunkState = StreamingRequestState::ReadingTrailers;
              } else {
                state->chunkState = StreamingRequestState::ReadingChunkData;
              }

              continue;
            }

            if (state->chunkState == StreamingRequestState::ReadingChunkData) {
              if (state->bodyBuffer.size() < state->currentChunkSize) {
                break;
              }

              const QByteArray chunk =
                  state->bodyBuffer.left(state->currentChunkSize);

              state->bodyBuffer.remove(0, state->currentChunkSize);

              state->receivedLength += chunk.size();

              if (state->receivedLength > MaxResponseBytes) {
                finish(failure(
                    QStringLiteral("Docker stream exceeded the 64 MiB limit"),
                    state->status));
                return;
              }

              // Emit only actual response body bytes.
              emit streamingData(
                  requestId,
                  QString::fromLatin1(chunk.constData(), chunk.size())
              );

              if (state->finished)
                return;

              state->chunkState = StreamingRequestState::ReadingChunkTerminator;

              continue;
            }

            if (state->chunkState ==
                StreamingRequestState::ReadingChunkTerminator) {
              if (state->bodyBuffer.size() < 2)
                break;

              if (state->bodyBuffer.left(2) != "\r\n") {
                finish(failure(QStringLiteral("Invalid HTTP chunk terminator"),
                               state->status));
                return;
              }

              state->bodyBuffer.remove(0, 2);

              state->chunkState = StreamingRequestState::ReadingChunkSize;

              continue;
            }

            if (state->chunkState == StreamingRequestState::ReadingTrailers) {
              // The terminal zero chunk is followed by either:
              //   CRLF
              // or:
              //   trailer fields + CRLF CRLF

              if (state->bodyBuffer.startsWith("\r\n")) {
                state->bodyBuffer.remove(0, 2);

                state->chunkState = StreamingRequestState::ChunkStreamFinished;

                finish({{QStringLiteral("success"), true},
                        {QStringLiteral("status"), state->status},
                        {QStringLiteral("data"), QVariant()},
                        {QStringLiteral("error"), QString()}});

                return;
              }

              const qsizetype trailerEnd =
                  state->bodyBuffer.indexOf("\r\n\r\n");

              if (trailerEnd < 0)
                break;

              state->bodyBuffer.remove(0, trailerEnd + 4);

              state->chunkState = StreamingRequestState::ChunkStreamFinished;

              finish({{QStringLiteral("success"), true},
                      {QStringLiteral("status"), state->status},
                      {QStringLiteral("data"), QVariant()},
                      {QStringLiteral("error"), QString()}});

              return;
            }

            if (state->chunkState ==
                StreamingRequestState::ChunkStreamFinished) {
              return;
            }
          }

          // Bound incomplete framing data. A complete chunk is
          // removed as soon as it is decoded.
          if (state->bodyBuffer.size() > MaxResponseBytes) {
            finish(failure(QStringLiteral("Incomplete HTTP chunk is too large"),
                           state->status));
          }

          return;
        }

        // ------------------------------------------------------------
        // Content-Length response.
        // ------------------------------------------------------------

        if (state->hasContentLength) {
          if (state->contentLength < 0) {
            finish(failure(QStringLiteral("Invalid HTTP Content-Length"),
                           state->status));
            return;
          }

          if (state->bodyBuffer.size() > MaxResponseBytes) {
            finish(failure(
                QStringLiteral("Docker response exceeded the 64 MiB limit"),
                state->status));
            return;
          }

          const qint64 remaining = state->contentLength - state->receivedLength;

          if (remaining <= 0) {
            finish({{QStringLiteral("success"), true},
                    {QStringLiteral("status"), state->status},
                    {QStringLiteral("data"), QVariant()},
                    {QStringLiteral("error"), QString()}});
            return;
          }

          const qsizetype amount =
              qMin<qint64>(remaining, state->bodyBuffer.size());

          if (amount > 0) {
            const QByteArray data = state->bodyBuffer.left(amount);

            state->bodyBuffer.remove(0, amount);
            state->receivedLength += amount;

            emit streamingData(
                requestId,
                QString::fromLatin1(data.constData(), data.size())
            );

            if (state->finished)
              return;
          }

          if (state->receivedLength >= state->contentLength) {
            finish({{QStringLiteral("success"), true},
                    {QStringLiteral("status"), state->status},
                    {QStringLiteral("data"), QVariant()},
                    {QStringLiteral("error"), QString()}});
          }

          return;
        }

        // ------------------------------------------------------------
        // Close-delimited response.
        //
        // No Content-Length and no chunked encoding means the body
        // continues until the server closes the connection.
        // ------------------------------------------------------------

        if (!state->bodyBuffer.isEmpty()) {
          const QByteArray data = state->bodyBuffer;
          state->bodyBuffer.clear();

          state->receivedLength += data.size();

          emit streamingData(
              requestId,
              QString::fromLatin1(data.constData(), data.size())
          );
        }
      });

  connect(state->socket, &QLocalSocket::disconnected, this, [state, finish]() {
    if (state->finished)
      return;

    if (!state->headersReceived) {
      finish(failure(
          QStringLiteral("Connection closed before HTTP headers arrived")));
      return;
    }

    if (state->status < 200 || state->status >= 300) {
      finish(makeHttpResult(state->status, state->errorBody));
      return;
    }

    if (state->chunked) {
      if (state->chunkState == StreamingRequestState::ChunkStreamFinished) {
        return;
      }

      finish(failure(QStringLiteral("Docker closed the connection before the "
                                    "chunked stream completed"),
                     state->status));
      return;
    }

    if (state->hasContentLength) {
      if (state->receivedLength < state->contentLength) {
        finish(failure(
            QStringLiteral(
                "Docker closed the connection before the response completed"),
            state->status));
        return;
      }

      finish({{QStringLiteral("success"), true},
              {QStringLiteral("status"), state->status},
              {QStringLiteral("data"), QVariant()},
              {QStringLiteral("error"), QString()}});

      return;
    }

    // A close-delimited response is complete when the peer closes.
    finish({{QStringLiteral("success"), true},
            {QStringLiteral("status"), state->status},
            {QStringLiteral("data"), QVariant()},
            {QStringLiteral("error"), QString()}});
  });

  connect(state->socket, &QLocalSocket::errorOccurred, this,
          [state, finish](QLocalSocket::LocalSocketError error) {
            if (state->finished)
              return;

            if (error == QLocalSocket::PeerClosedError)
              return;

            finish(failure(state->socket->errorString()));
          });

  state->connectionTimer->start(ConnectionTimeoutMs);

  state->socket->connectToServer(socketPath, QIODevice::ReadWrite);

  return requestId;
}

// ============================================================================
// Stop streaming request
// ============================================================================
void UnixSocketBridge::stopStreamingRequest(const QString &requestId)
{
    // Stop HTTP/HTTPS stream, if present.
    auto httpReply = m_activeHttpStreamingRequests.take(requestId);

    if (httpReply) {
        httpReply->abort();
        httpReply->deleteLater();
    }

    // Stop Unix-socket stream, if present.
    auto *state = m_activeStreamingRequests.take(requestId);

    if (!state)
        return;

    state->finished = true;

    if (state->socket) {
        state->socket->abort();
        state->socket->deleteLater();
    }
}


// ============================================================================
// Start HTTP streaming request
// ============================================================================

QString UnixSocketBridge::startHttpStreamingRequest(
    const QString &url,
    const QString &requestId)
{
    auto finishImmediately = [this, &requestId](const QVariantMap &result) {
        QMetaObject::invokeMethod(this, [this, requestId, result] {
            emit streamingFinished(requestId, result);
        }, Qt::QueuedConnection);
    };

    if (requestId.isEmpty()) {
        finishImmediately({
            {"success", false},
            {"status", 0},
            {"data", QVariant()},
            {"error", QStringLiteral("Request ID must not be empty")}
        });
        return {};
    }

    const QUrl requestUrl(url);

    if (!requestUrl.isValid() ||
        (requestUrl.scheme() != QStringLiteral("http") &&
         requestUrl.scheme() != QStringLiteral("https")) ||
        requestUrl.host().isEmpty()) {

        finishImmediately({
            {"success", false},
            {"status", 0},
            {"data", QVariant()},
            {"error", QStringLiteral("Invalid HTTP streaming URL")}
        });
        return {};
    }

    // Replace an existing HTTP stream with the same ID.
    stopStreamingRequest(requestId);

    QNetworkRequest request(requestUrl);
    request.setRawHeader("Accept", "application/vnd.docker.raw-stream");

    auto *reply = m_networkAccessManager->get(request);

    m_activeHttpStreamingRequests.insert(requestId, reply);

    struct StreamState {
        bool responseAccepted = false;
        bool completed = false;
        QByteArray errorBody;
        QPointer<QTimer> connectionTimer;
    };

    const auto state = QSharedPointer<StreamState>::create();

    // Only time out the initial connection/response headers.
    // An established log stream must not have a total-duration timeout.
    auto *connectionTimer = new QTimer(reply);
    connectionTimer->setSingleShot(true);
    state->connectionTimer = connectionTimer;

    auto finish = [this, requestId, reply, state](const QVariantMap &result) {
        if (state->completed)
            return;

        state->completed = true;

        if (state->connectionTimer)
            state->connectionTimer->stop();

        if (m_activeHttpStreamingRequests.value(requestId) == reply)
            m_activeHttpStreamingRequests.remove(requestId);

        emit streamingFinished(requestId, result);

        reply->deleteLater();
    };

    auto checkResponse = [reply, state, finish]() {
        if (state->responseAccepted || state->completed)
            return;

        const QVariant statusValue =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);

        if (!statusValue.isValid())
            return;

        const int status = statusValue.toInt();

        if (status >= 200 && status < 300) {
            state->responseAccepted = true;

            if (state->connectionTimer)
                state->connectionTimer->stop();

            return;
        }

        // An HTTP error response is not a Docker log stream.
        // Its body is collected and reported when the reply finishes.
    };

    connect(connectionTimer, &QTimer::timeout, this,
            [this, requestId, reply, finish]() {
        if (m_activeHttpStreamingRequests.value(requestId) != reply)
            return;

        finish({
            {"success", false},
            {"status", 0},
            {"data", QVariant()},
            {"error", QStringLiteral("HTTP streaming connection timed out")}
        });

        reply->abort();
    });

    connect(reply, &QNetworkReply::metaDataChanged,
            this, checkResponse);

    connect(reply, &QIODevice::readyRead, this,
            [this, requestId, reply, state, checkResponse]() {
        if (state->completed)
            return;

        checkResponse();

        const QByteArray data = reply->readAll();

        if (data.isEmpty())
            return;

        if (state->responseAccepted) {
            emit streamingData(
                requestId,
                QString::fromLatin1(data.constData(), data.size())
            );
        } else {
            // Keep HTTP error bodies bounded.
            constexpr qsizetype MaxErrorBodyBytes = 1024 * 1024;

            const qsizetype remaining =
                MaxErrorBodyBytes - state->errorBody.size();

            if (remaining > 0)
                state->errorBody.append(data.left(remaining));
        }
    });

    connect(reply, &QNetworkReply::finished, this,
            [this, requestId, reply, state, finish, checkResponse]() {
        if (state->completed)
            return;

        checkResponse();

        // Drain any remaining bytes.
        const QByteArray remaining = reply->readAll();

        if (state->responseAccepted) {
            if (!remaining.isEmpty())
                emit streamingData(
                    requestId,
                    QString::fromLatin1(remaining.constData(), remaining.size())
                );

            const int status =
                reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

            finish({
                {"success", status >= 200 && status < 300},
                {"status", status},
                {"data", QVariant()},
                {"error", QString()}
            });

            return;
        }

        if (!remaining.isEmpty()) {
            constexpr qsizetype MaxErrorBodyBytes = 1024 * 1024;

            const qsizetype available =
                MaxErrorBodyBytes - state->errorBody.size();

            if (available > 0)
                state->errorBody.append(remaining.left(available));
        }

        const int status =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        QString error = reply->errorString();

        QJsonParseError jsonError;
        const QJsonDocument document =
            QJsonDocument::fromJson(state->errorBody, &jsonError);

        if (jsonError.error == QJsonParseError::NoError &&
            document.isObject()) {

            const QString message =
                document.object().value(QStringLiteral("message")).toString();

            if (!message.isEmpty())
                error = message;
        }

        if (status > 0)
            error = QStringLiteral("HTTP %1: %2").arg(status).arg(error);

        finish({
            {"success", false},
            {"status", status},
            {"data", QString::fromUtf8(state->errorBody)},
            {"error", error}
        });
    });

    connectionTimer->start(10000);

    qDebug().noquote()
        << "[DockHub HTTP] Starting log stream:" << requestUrl.toString();

    return requestId;
}
