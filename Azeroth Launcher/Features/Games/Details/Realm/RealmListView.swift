//
//  RealmListView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

private struct RealmSheet: Identifiable {
    let id = UUID()
    let server: RealmServer?
}

struct RealmListView: View {
    let installation: GameInstallation
    @Environment(\.locale) private var appLocale
    @Environment(\.dismiss) private var dismiss

    @State private var servers: [RealmServer] = []
    @State private var currentAddress: String?
    
    @State private var activeSheet: RealmSheet?
    
    @State private var errorMessage: String?
    @State private var isErrorPresented = false
    @State private var isSuccessPresented = false

    private let fileService = RealmListFileService()
    private let store = RealmServerStore()
    

    private var currentServer: RealmServer? {
        guard let currentAddress else {
            return nil
        }

        return servers.first {
            $0.address.caseInsensitiveCompare(currentAddress) == .orderedSame
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            currentRealmSection
            savedRealmsSection
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadData()
        }
        .sheet(item: $activeSheet) { sheet in
            AddRealmView(server: sheet.server) { server in
                let success: Bool

                if sheet.server != nil {
                    success = store.update(
                        server,
                        for: installation.edition
                    )
                } else {
                    success = store.add(
                        server,
                        for: installation.edition
                    )
                }

                guard success else {
                    errorMessage = "A realm with this address already exists."
                    isErrorPresented = true
                    return
                }

                loadData()
                activeSheet = nil
            }
            .environment(\.locale, appLocale)
        }
        .alert("Something went wrong", isPresented: $isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
        .alert("Realm updated", isPresented: $isSuccessPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The game server address has been updated successfully.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("REALM MANAGER")
                    .font(.system(size: 22, weight: .black))
                    .tracking(1.2)

                Text(installation.edition.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var currentRealmSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                "CURRENT REALM",
                subtitle: "The server configured in your game client."
            )

            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                    .frame(width: 48, height: 48)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Group {
                        if let currentServer {
                            Text(currentServer.name)
                        } else {
                            Text("Custom Realm")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))

                    Text(currentAddress ?? "Not configured")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(currentAddress == nil ? .gray : .green)
                    .frame(width: 8, height: 8)
            }
            .padding(16)
            .background(.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1)
            }
        }
    }

    private var savedRealmsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(
                    "SAVED REALMS",
                    subtitle: "Manage your saved game servers."
                )

                Spacer()

                Button {
                    activeSheet = RealmSheet(server: nil)
                } label: {
                    Label("Add Realm", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if servers.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(servers) { server in
                        RealmRowView(
                            server: server,
                            isCurrent: server.address.caseInsensitiveCompare(
                                currentAddress ?? ""
                            ) == .orderedSame,
                            onApply: {
                                apply(server)
                            },
                            onEdit: {
                                activeSheet = RealmSheet(server: server)
                            },
                            onDelete: {
                                delete(server)
                            }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No saved realms")
                .font(.system(size: 14, weight: .semibold))

            Text("Add your favorite game servers to switch between them easily.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .background(.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionTitle(_ title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func loadData() {
        servers = store.load(
            for: installation.edition
        )
        do {
            currentAddress = try fileService.readCurrentRealm(
                installationPath: installation.installationPath
            )
        } catch {
            showError(error)
        }
    }

    private func apply(_ server: RealmServer) {
        do {
            try fileService.applyRealm(
                address: server.address,
                installationPath: installation.installationPath
            )

            currentAddress = server.address
            isSuccessPresented = true
        } catch {
            showError(error)
        }
    }

    private func delete(_ server: RealmServer) {
        store.remove(
            id: server.id,
            for: installation.edition
        )

        loadData()
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isErrorPresented = true
    }
}
