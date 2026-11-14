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
        VStack(alignment: .leading, spacing: 25) {
            header

            currentRealmSection

            savedRealmsSection

            Spacer(minLength: 0)
        }
        .padding(30)
        .frame(minWidth: 620, minHeight: 570)
        .background(LauncherTheme.background)
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
        HStack(spacing: 15) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 23))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 54, height: 54)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text("Realm Manager")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(installation.edition.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LauncherTheme.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(LauncherTheme.elevatedSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    private var currentRealmSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader(
                "CURRENT REALM",
                subtitle: "The server currently configured in your game client."
            )

            HStack(spacing: 15) {
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundStyle(LauncherTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(LauncherTheme.accentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentServer?.name ?? "Custom Realm")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text(currentAddress ?? "Not configured")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LauncherTheme.secondaryText)
                        .textSelection(.enabled)
                }

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(currentAddress == nil ? .gray : .green)
                        .frame(width: 7, height: 7)

                    Text(currentAddress == nil ? "NOT CONFIGURED" : "ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(
                            currentAddress == nil
                                ? LauncherTheme.secondaryText
                                : .green
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(LauncherTheme.elevatedSurface)
                .clipShape(Capsule())
            }
            .padding(17)
            .background(LauncherTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(LauncherTheme.separator, lineWidth: 1)
            }
        }
    }

    private var savedRealmsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionHeader(
                    "SAVED REALMS",
                    subtitle: "Manage your saved game servers."
                )

                Spacer()

                Button {
                    activeSheet = RealmSheet(server: nil)
                } label: {
                    Label("Add Realm", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(LauncherTheme.accent)
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
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 30))
                .foregroundStyle(LauncherTheme.accentSecondary)
                .frame(width: 58, height: 58)
                .background(LauncherTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("No saved realms")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LauncherTheme.primaryText)

            Text("Add your favorite game servers to switch between them easily.")
                .font(.system(size: 11))
                .foregroundStyle(LauncherTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    private func sectionHeader(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(LauncherTheme.primaryText)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(LauncherTheme.secondaryText)
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
