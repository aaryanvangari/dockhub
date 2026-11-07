#pragma once

#include <QObject>
#include <QVariant>
#include <QString>
#include <QHash>
#include <QLocalSocket>
#include <QTimer>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

struct StreamingRequestState
{
    QString requestId;
    QLocalSocket *socket = nullptr;
    QPointer<QTimer> timeoutTimer;
    QPointer<QTimer> readTimer;
    QString endpoint;
    QString method;
    QByteArray body;
    QByteArray buffer;
    bool finished = false;
    QVariantMap lastResult;
    bool headersReceived = false;
    bool headersComplete = false;
    qsizetype receivedLength = 0;
    bool chunked = false;
    qsizetype contentLength = 0;

    void stop() {
        if (timeoutTimer.data()) {
            timeoutTimer.data()->stop();
        }
        if (readTimer.data()) {
            readTimer.data()->stop();
        }
    }
};

class UnixSocketBridge : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit UnixSocketBridge(QObject *parent = nullptr);

    // Asynchronous Docker Engine API request over a Unix domain socket.
    // body should be a JSON string, or null/undefined for requests without a body.
    Q_INVOKABLE void sendHttpRequest(const QString &socketPath,
                                      const QString &method,
                                      const QString &endpoint,
                                      const QVariant &body,
                                      const QString &requestId);

signals:
    void requestFinished(const QString &requestId, const QVariantMap &result);
    void streamingData(const QString &requestId, const QByteArray &data);
    void streamingFinished(const QString &requestId, const QVariantMap &result);

public Q_SLOTS:
    // Start a streaming HTTP request over a Unix domain socket
    Q_INVOKABLE QString startStreamingRequest(const QString &socketPath,
                                               const QString &method,
                                               const QString &endpoint,
                                               const QVariant &body,
                                               const QString &requestId);

    // Stop a streaming HTTP request
    Q_INVOKABLE void stopStreamingRequest(const QString &requestId);

private:
    QHash<QString, StreamingRequestState *> m_activeStreamingRequests;
};
