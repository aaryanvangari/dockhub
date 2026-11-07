#pragma once

#include <QByteArray>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class StreamingRequestState;

class UnixSocketBridge : public QObject {
  Q_OBJECT
  QML_ELEMENT

public:
  explicit UnixSocketBridge(QObject *parent = nullptr);
  ~UnixSocketBridge() override;

  // One-shot Docker Engine API request.
  Q_INVOKABLE void sendHttpRequest(const QString &socketPath,
                                   const QString &method,
                                   const QString &endpoint,
                                   const QVariant &body,
                                   const QString &requestId);

  // Start a persistent Docker API streaming request.
  // Returns the request ID, or an empty string if validation fails.
  Q_INVOKABLE QString startStreamingRequest(const QString &socketPath,
                                            const QString &method,
                                            const QString &endpoint,
                                            const QVariant &body,
                                            const QString &requestId);

  // Stop and clean up a persistent request.
  Q_INVOKABLE void stopStreamingRequest(const QString &requestId);

signals:
  void requestFinished(const QString &requestId, const QVariantMap &result);

  // Emits decoded HTTP response-body bytes.
  // Docker's own multiplexed log frames remain untouched.
  void streamingData(const QString &requestId, const QByteArray &data);

  void streamingFinished(const QString &requestId, const QVariantMap &result);

private:
  QHash<QString, StreamingRequestState *> m_activeStreamingRequests;
};
