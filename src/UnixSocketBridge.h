#pragma once

#include <QByteArray>
#include <QHash>
#include <QPointer>
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class StreamingRequestState;
class QNetworkAccessManager;
class QNetworkReply;

class UnixSocketBridge : public QObject {
  Q_OBJECT
  QML_ELEMENT

public:
  explicit UnixSocketBridge(QObject *parent = nullptr);
  ~UnixSocketBridge() override;

  // Persistent Docker log streaming over HTTP/HTTPS.
  Q_INVOKABLE QString startHttpStreamingRequest(
      const QString &url,
      const QString &requestId);

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
  void streamingData(const QString &requestId, const QString &data);

  void streamingFinished(const QString &requestId, const QVariantMap &result);

private:
  QHash<QString, StreamingRequestState *> m_activeStreamingRequests;
  QNetworkAccessManager *m_networkAccessManager = nullptr;
  QHash<QString, QPointer<QNetworkReply>> m_activeHttpStreamingRequests;
};
