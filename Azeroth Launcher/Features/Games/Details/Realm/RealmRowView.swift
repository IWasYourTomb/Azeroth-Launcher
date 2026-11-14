//
//  RealmRowView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI
import Network

struct RealmRowView: View {
    let server: RealmServer
    let isCurrent: Bool

    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var connectionStatus: RealmConnectionStatus = .unknown
    @State private var connection: NWConnection?
    @State private var timeoutWorkItem: DispatchWorkItem?

    private let connectionQueue = DispatchQueue(
        label: "com.azerothlauncher.realm-connection"
    )

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
                .frame(width: 42, height: 42)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(.system(size: 14, weight: .semibold))

                    if isCurrent {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(server.address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                connectionStatusView
            }

            Spacer()

            Button {
                checkConnection()
            } label: {
                Group {
                    if connectionStatus == .checking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "network")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(connectionStatus == .checking)
            .help("Check connection")

            if !isCurrent {
                Button(action: onApply) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .help("Apply realm")
            }

            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                if !isCurrent {
                    Button(action: onApply) {
                        Label("Apply", systemImage: "checkmark")
                    }
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        }
        .onDisappear {
            stopConnection()
        }
    }

    private var connectionStatusView: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor)
        }
    }

    private var statusTitle: LocalizedStringKey {
        switch connectionStatus {
        case .unknown:
            return "Connection not checked"
        case .checking:
            return "Checking connection..."
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        }
    }

    private var statusColor: Color {
        switch connectionStatus {
        case .unknown:
            return .secondary
        case .checking:
            return .orange
        case .online:
            return .green
        case .offline:
            return .red
        }
    }

    private func checkConnection() {
        stopConnection()

        guard let endpoint = makeEndpoint(from: server.address) else {
            connectionStatus = .offline
            return
        }

        connectionStatus = .checking

        let newConnection = NWConnection(
            to: endpoint,
            using: .tcp
        )

        connection = newConnection

        let timeout = DispatchWorkItem {
            DispatchQueue.main.async {
                guard connectionStatus == .checking else {
                    return
                }

                connectionStatus = .offline
                newConnection.cancel()
                connection = nil
                timeoutWorkItem = nil
            }
        }

        timeoutWorkItem = timeout

        newConnection.stateUpdateHandler = { state in
            print("[RealmCheck] \(server.address): \(state)")

            switch state {
            case .ready:
                print("[RealmCheck] TCP connection established")

                DispatchQueue.main.async {
                    timeoutWorkItem?.cancel()
                    timeoutWorkItem = nil
                    connectionStatus = .online
                    newConnection.cancel()
                    connection = nil
                }

            case .waiting(let error):
                print("[RealmCheck] Waiting: \(error)")

            case .failed(let error):
                print("[RealmCheck] Failed: \(error)")

                DispatchQueue.main.async {
                    timeoutWorkItem?.cancel()
                    timeoutWorkItem = nil
                    connectionStatus = .offline
                    connection = nil
                }

            case .cancelled:
                print("[RealmCheck] Cancelled")

            default:
                print("[RealmCheck] State: \(state)")
            }
        }

        connectionQueue.asyncAfter(
            deadline: .now() + 5,
            execute: timeout
        )

        newConnection.start(queue: connectionQueue)
    }

    private func stopConnection() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
    }

    private func makeEndpoint(from address: String) -> NWEndpoint? {
        let value = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !value.isEmpty else {
            return nil
        }

        let components = URLComponents(
            string: "tcp://\(value)"
        )

        guard let host = components?.host,
              !host.isEmpty,
              components?.path.isEmpty == true,
              components?.query == nil,
              components?.user == nil else {
            return nil
        }

        let portNumber = components?.port ?? 3724

        guard let port = NWEndpoint.Port(
            rawValue: UInt16(portNumber)
        ) else {
            return nil
        }

        return .hostPort(
            host: NWEndpoint.Host(host),
            port: port
        )
    }
}
