#pragma once

#include <QObject>
#include <QVariant>
#include <QString>
#include <QtQml/qqmlregistration.h>

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
};