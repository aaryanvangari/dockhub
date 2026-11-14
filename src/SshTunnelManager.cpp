#include "SshTunnelManager.h"

#include <QDir>
#include <QHostAddress>
#include <QProcess>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QDebug>

// -----------------------------------------------------------------------------
// Internal tunnel state
// -----------------------------------------------------------------------------

class SshTunnelState : public QObject
{
public:
    explicit SshTunnelState(QObject *parent = nullptr)
        : QObject(parent)
    {
        process = new QProcess(this);
        readinessTimer = new QTimer(this);
        timeoutTimer = new QTimer(this);

        readinessTimer->setInterval(100);
        timeoutTimer->setSingleShot(true);
    }

    QString serverId;
    QString localUrl;
    QString errorOutput;

    quint16 localPort = 0;

    bool ready = false;
    bool probeInProgress = false;

    QProcess *process = nullptr;
    QTimer *readinessTimer = nullptr;
    QTimer *timeoutTimer = nullptr;
};

// -----------------------------------------------------------------------------
// SshTunnelManager
// -----------------------------------------------------------------------------

SshTunnelManager::SshTunnelManager(QObject *parent)
    : QObject(parent)
{
}

SshTunnelManager::~SshTunnelManager()
{
    const auto states = m_tunnels.values();
    m_tunnels.clear();

    for (auto *state : states) {
        state->readinessTimer->stop();
        state->timeoutTimer->stop();

        if (state->process->state() != QProcess::NotRunning) {
            state->process->terminate();

            if (!state->process->waitForFinished(1500)) {
                state->process->kill();
                state->process->waitForFinished(1000);
            }
        }

        delete state;
    }
}

// -----------------------------------------------------------------------------
// Start tunnel
// -----------------------------------------------------------------------------

bool SshTunnelManager::startTunnel(
    const QString &serverId,
    const QString &sshHost,
    int sshPort,
    const QString &sshUser,
    const QString &identityFile,
    const QString &remoteSocketPath)
{
    if (serverId.trimmed().isEmpty()) {
        emit tunnelFailed(serverId, QStringLiteral("Server ID is empty."));
        return false;
    }

    if (sshHost.trimmed().isEmpty()) {
        emit tunnelFailed(serverId, QStringLiteral("SSH host is empty."));
        return false;
    }

    if (sshPort < 1 || sshPort > 65535) {
        emit tunnelFailed(serverId, QStringLiteral("Invalid SSH port."));
        return false;
    }

    if (remoteSocketPath.trimmed().isEmpty()) {
        emit tunnelFailed(
            serverId,
            QStringLiteral("Remote Docker socket path is empty.")
        );
        return false;
    }

    // Replace an existing tunnel for this server.
    stopTunnel(serverId);

    // Allocate an available local TCP port.
    QTcpServer portReservation;

    if (!portReservation.listen(QHostAddress::LocalHost, 0)) {
        emit tunnelFailed(
            serverId,
            QStringLiteral("Unable to allocate a local port.")
        );
        return false;
    }

    const quint16 localPort = portReservation.serverPort();

    // Release the temporary reservation.
    // OpenSSH will bind this port when it starts.
    portReservation.close();

    auto *state = new SshTunnelState(this);

    state->serverId = serverId;
    state->localPort = localPort;
    state->localUrl = QStringLiteral("http://127.0.0.1:%1")
                          .arg(localPort);

    m_tunnels.insert(serverId, state);

    // -------------------------------------------------------------------------
    // Construct OpenSSH arguments.
    // -------------------------------------------------------------------------

    QStringList arguments;

    arguments << QStringLiteral("-N");
    arguments << QStringLiteral("-T");

    if (sshPort != 22) {
        arguments << QStringLiteral("-p");
        arguments << QString::number(sshPort);
    }

    arguments << QStringLiteral("-o");
    arguments << QStringLiteral("BatchMode=yes");

    arguments << QStringLiteral("-o");
    arguments << QStringLiteral("ExitOnForwardFailure=yes");

    arguments << QStringLiteral("-o");
    arguments << QStringLiteral("ServerAliveInterval=30");

    arguments << QStringLiteral("-o");
    arguments << QStringLiteral("ServerAliveCountMax=3");

    arguments << QStringLiteral("-o");
    arguments << QStringLiteral("ConnectTimeout=10");

    // Bind exclusively to localhost.
    arguments << QStringLiteral("-L");
    arguments << QStringLiteral("127.0.0.1:%1:%2")
                      .arg(localPort)
                      .arg(remoteSocketPath);

    // Optional identity file.
    if (!identityFile.trimmed().isEmpty()) {
        QString expandedIdentity = identityFile.trimmed();

        if (expandedIdentity == QStringLiteral("~")) {
            expandedIdentity = QDir::homePath();
        } else if (expandedIdentity.startsWith(QStringLiteral("~/"))) {
            expandedIdentity = QDir::home().filePath(
                expandedIdentity.mid(2)
            );
        }

        arguments << QStringLiteral("-i");
        arguments << expandedIdentity;
    }

    // SSH config aliases work when no explicit username is supplied.
    QString target = sshHost.trimmed();

    if (!sshUser.trimmed().isEmpty()) {
        target = sshUser.trimmed() + QStringLiteral("@") + target;
    }

    arguments << target;

    // -------------------------------------------------------------------------
    // Process output.
    // -------------------------------------------------------------------------

    connect(
        state->process,
        &QProcess::readyReadStandardError,
        this,
        [this, state]() {
            const QString output = QString::fromLocal8Bit(
                state->process->readAllStandardError()
            );

            state->errorOutput += output;

            emit tunnelOutput(state->serverId, output);
        }
    );

    connect(
        state->process,
        &QProcess::readyReadStandardOutput,
        this,
        [this, state]() {
            const QString output = QString::fromLocal8Bit(
                state->process->readAllStandardOutput()
            );

            emit tunnelOutput(state->serverId, output);
        }
    );

    // -------------------------------------------------------------------------
    // SSH process started.
    // -------------------------------------------------------------------------

    connect(
        state->process,
        &QProcess::started,
        this,
        [this, state]() {
            state->readinessTimer->start();
            state->timeoutTimer->start(10000);
        }
    );

    // -------------------------------------------------------------------------
    // Check whether the local forwarding listener is ready.
    // -------------------------------------------------------------------------

    connect(
        state->readinessTimer,
        &QTimer::timeout,
        this,
        [this, state]() {
            if (state->ready || state->probeInProgress)
                return;

            state->probeInProgress = true;

            auto *probe = new QTcpSocket(state);

            connect(
                probe,
                &QTcpSocket::connected,
                this,
                [this, state, probe]() {
                    probe->disconnect(this);
                    probe->deleteLater();

                    state->probeInProgress = false;

                    if (!m_tunnels.contains(state->serverId))
                        return;

                    state->ready = true;

                    state->readinessTimer->stop();
                    state->timeoutTimer->stop();

                    emit tunnelStarted(
                        state->serverId,
                        state->localUrl
                    );
                }
            );

            connect(
                probe,
                &QTcpSocket::errorOccurred,
                this,
                [this, state, probe](QAbstractSocket::SocketError) {
                    probe->disconnect(this);
                    probe->deleteLater();
            
                    state->probeInProgress = false;
                }
            );

            probe->connectToHost(
                QHostAddress::LocalHost,
                state->localPort
            );
        }
    );

    // -------------------------------------------------------------------------
    // Startup timeout.
    // -------------------------------------------------------------------------

    connect(
        state->timeoutTimer,
        &QTimer::timeout,
        this,
        [this, state]() {
            QString error = QStringLiteral(
                "SSH tunnel did not become ready within 10 seconds."
            );

            if (!state->errorOutput.trimmed().isEmpty()) {
                error += QStringLiteral("\n");
                error += state->errorOutput.trimmed();
            }

            handleTunnelFailure(state, error);
        }
    );

    // -------------------------------------------------------------------------
    // Process errors.
    // -------------------------------------------------------------------------

    connect(
        state->process,
        &QProcess::errorOccurred,
        this,
        [this, state](QProcess::ProcessError error) {
            if (error == QProcess::FailedToStart) {
                handleTunnelFailure(
                    state,
                    QStringLiteral(
                        "Unable to start OpenSSH. "
                        "Check that the ssh executable is installed."
                    )
                );
            }
        }
    );

    // -------------------------------------------------------------------------
    // Process termination.
    // -------------------------------------------------------------------------

    connect(
        state->process,
        qOverload<int, QProcess::ExitStatus>(
            &QProcess::finished
        ),
        this,
        [this, state](int exitCode, QProcess::ExitStatus exitStatus) {
            handleProcessFinished(state, exitCode, exitStatus);
        }
    );

    // Start OpenSSH.
    state->process->start(
        QStringLiteral("ssh"),
        arguments
    );

    return true;
}

// -----------------------------------------------------------------------------
// Handle startup failure
// -----------------------------------------------------------------------------

void SshTunnelManager::handleTunnelFailure(
    SshTunnelState *state,
    const QString &error)
{
    if (!state)
        return;

    const QString serverId = state->serverId;

    if (m_tunnels.value(serverId) != state)
        return;

    m_tunnels.remove(serverId);

    state->readinessTimer->stop();
    state->timeoutTimer->stop();

    emit tunnelFailed(serverId, error);

    // Terminate the SSH process asynchronously.
    if (state->process->state() != QProcess::NotRunning) {
        state->process->terminate();

        QProcess *process = state->process;

        QTimer::singleShot(1500, state, [process]() {
            if (process->state() != QProcess::NotRunning)
                process->kill();
        });
    } else {
        state->deleteLater();
    }
}

// -----------------------------------------------------------------------------
// Handle SSH process termination
// -----------------------------------------------------------------------------

void SshTunnelManager::handleProcessFinished(
    SshTunnelState *state,
    int exitCode,
    QProcess::ExitStatus exitStatus)
{
    if (!state)
        return;

    const QString serverId = state->serverId;

    if (m_tunnels.value(serverId) != state) {
        state->deleteLater();
        return;
    }

    m_tunnels.remove(serverId);

    state->readinessTimer->stop();
    state->timeoutTimer->stop();

    QString error;

    if (exitStatus == QProcess::CrashExit) {
        error = QStringLiteral("SSH process crashed.");
    } else {
        error = QStringLiteral("SSH process exited with code %1.")
                    .arg(exitCode);
    }

    if (!state->errorOutput.trimmed().isEmpty()) {
        error += QStringLiteral("\n");
        error += state->errorOutput.trimmed();
    }

    emit tunnelFailed(serverId, error);

    state->deleteLater();
}

// -----------------------------------------------------------------------------
// Stop one tunnel
// -----------------------------------------------------------------------------

void SshTunnelManager::stopTunnel(const QString &serverId)
{
    auto *state = m_tunnels.take(serverId);

    if (!state)
        return;

    state->readinessTimer->stop();
    state->timeoutTimer->stop();

    emit tunnelStopped(serverId);

    if (state->process->state() != QProcess::NotRunning) {
        QProcess *process = state->process;

        process->terminate();

        // handleProcessFinished() will delete the state after SSH exits.
        QTimer::singleShot(1500, state, [process]() {
            if (process->state() != QProcess::NotRunning)
                process->kill();
        });
    } else {
        state->deleteLater();
    }
}

// -----------------------------------------------------------------------------
// Stop all tunnels
// -----------------------------------------------------------------------------

void SshTunnelManager::stopAllTunnels()
{
    const QStringList serverIds = m_tunnels.keys();

    for (const QString &serverId : serverIds)
        stopTunnel(serverId);
}

// -----------------------------------------------------------------------------
// Get tunnel URL
// -----------------------------------------------------------------------------

QString SshTunnelManager::tunnelUrl(const QString &serverId) const
{
    const auto *state = m_tunnels.value(serverId);

    if (!state || !state->ready)
        return {};

    return state->localUrl;
}

// -----------------------------------------------------------------------------
// Check tunnel state
// -----------------------------------------------------------------------------

bool SshTunnelManager::isTunnelActive(const QString &serverId) const
{
    const auto *state = m_tunnels.value(serverId);

    return state && state->ready;
}