#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QProcess>
#include <QtQml/qqmlregistration.h>

class SshTunnelState;

class SshTunnelManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit SshTunnelManager(QObject *parent = nullptr);
    ~SshTunnelManager() override;

    // Starts an SSH tunnel to a remote Docker Unix socket.
    // Returns false if the configuration is invalid or startup is rejected.
    Q_INVOKABLE bool startTunnel(
        const QString &serverId,
        const QString &sshHost,
        int sshPort,
        const QString &sshUser,
        const QString &identityFile,
        const QString &remoteSocketPath
    );

    // Stops a specific server's SSH tunnel.
    Q_INVOKABLE void stopTunnel(const QString &serverId);

    // Stops every active SSH tunnel.
    Q_INVOKABLE void stopAllTunnels();

    // Returns the local HTTP endpoint when the tunnel exists.
    Q_INVOKABLE QString tunnelUrl(const QString &serverId) const;

    // Returns whether a tunnel has completed its local startup check.
    Q_INVOKABLE bool isTunnelActive(const QString &serverId) const;

signals:
    void tunnelStarted(
        const QString &serverId,
        const QString &localUrl
    );

    void tunnelFailed(
        const QString &serverId,
        const QString &error
    );

    void tunnelStopped(const QString &serverId);

    void tunnelOutput(
        const QString &serverId,
        const QString &output
    );

private:
    void handleTunnelFailure(
        SshTunnelState *state,
        const QString &error
    );

    void handleProcessFinished(
        SshTunnelState *state,
        int exitCode,
        QProcess::ExitStatus exitStatus
    );

    QHash<QString, SshTunnelState *> m_tunnels;
};