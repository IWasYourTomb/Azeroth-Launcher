//
//  AddonsView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AddonsView: View {
    let installation: GameInstallation

    private let addonInstaller = AddonInstaller()
    private let addonManager = AddonManager()
    private let fileManager = FileManager.default

    @State private var isImporterPresented = false
    @State private var addons: [GameAddon] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false

    @State private var addonToDelete: GameAddon?
    @State private var isDeleteConfirmationPresented = false

    private var filteredAddons: [GameAddon] {
        guard !searchText.isEmpty else {
            return addons
        }

        return addons.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.folderName.localizedCaseInsensitiveContains(searchText) ||
            ($0.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var enabledCount: Int {
        addons.filter(\.isEnabled).count
    }

    private var disabledCount: Int {
        addons.filter { !$0.isEnabled }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            header

            if isLoading {
                loadingView
            } else if let errorMessage {
                errorView(errorMessage)
            } else if addons.isEmpty {
                emptyState
            } else {
                addonsList
            }
        }
        .onAppear {
            scanAddons()
        }
        .alert(
            "Something went wrong",
            isPresented: $isErrorPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
        .confirmationDialog(
            "Delete Addon?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let addon = addonToDelete {
                    deleteAddon(addon)
                }
            }

            Button("Cancel", role: .cancel) {
                addonToDelete = nil
            }
        } message: {
            Text(
                "This action will permanently delete the addon and all its files."
            )
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let archiveURL = urls.first else {
                    return
                }

                installAddon(from: archiveURL)

            case .failure(let error):
                showError(error)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(LauncherTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(LauncherTheme.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Installed Addons")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LauncherTheme.primaryText)

                        Text("Manage installed game modifications")
                            .font(.system(size: 10))
                            .foregroundStyle(LauncherTheme.secondaryText)
                    }
                }

                Spacer()

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Install Addon", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(LauncherTheme.accent)
                .disabled(isLoading)

                Button {
                    scanAddons()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LauncherTheme.primaryText)
                        .frame(width: 32, height: 32)
                        .background(LauncherTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Refresh addons")
            }

            HStack(spacing: 10) {
                statisticCard(
                    title: "Total",
                    value: addons.count,
                    icon: "square.grid.2x2.fill",
                    color: LauncherTheme.accent
                )

                statisticCard(
                    title: "Enabled",
                    value: enabledCount,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                statisticCard(
                    title: "Disabled",
                    value: disabledCount,
                    icon: "pause.circle.fill",
                    color: LauncherTheme.secondaryText
                )
            }
        }
    }

    private func statisticCard(
        title: LocalizedStringKey,
        value: Int,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)
                    .monospacedDigit()

                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    // MARK: - Addons List

    private var addonsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField

            HStack {
                Text("ADDON LIST")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(LauncherTheme.secondaryText)

                Spacer()

                Text("\(filteredAddons.count) / \(addons.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LauncherTheme.secondaryText)
                    .monospacedDigit()
            }
            .padding(.top, 3)

            if filteredAddons.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(height: 140)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredAddons) { addon in
                        AddonRowView(
                            addon: addon,
                            edition: installation.edition,
                            onToggle: toggleAddon,
                            onDelete: requestDelete,
                            onReveal: revealAddon
                        )
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(LauncherTheme.secondaryText)

            TextField("Search addons...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(LauncherTheme.primaryText)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(LauncherTheme.accent)

            Text("Scanning addons...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LauncherTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 30))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 68, height: 68)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("No addons found")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LauncherTheme.primaryText)

            Text("Addons installed in Interface/AddOns will appear here.")
                .font(.system(size: 11))
                .foregroundStyle(LauncherTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                scanAddons()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(LauncherTheme.accent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(LauncherTheme.accent)

            Text("Unable to scan addons")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LauncherTheme.primaryText)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(LauncherTheme.secondaryText)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            Button("Try Again") {
                scanAddons()
            }
            .buttonStyle(.bordered)
            .tint(LauncherTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    private func scanAddons() {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            addons = try addonManager.scan(
                installation: installation
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func installAddon(from archiveURL: URL) {
        let hasAccess = archiveURL.startAccessingSecurityScopedResource()

        defer {
            if hasAccess {
                archiveURL.stopAccessingSecurityScopedResource()
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            let installedNames = try addonInstaller.install(
                from: archiveURL,
                into: installation
            )

            addons = try addonManager.scan(
                installation: installation
            )

            print(
                "[AddonInstaller] Installed: \(installedNames.joined(separator: ", "))"
            )
        } catch {
            errorMessage = error.localizedDescription
            isErrorPresented = true
        }

        isLoading = false
    }

    // MARK: - Toggle

    private func toggleAddon(_ addon: GameAddon) {
        guard !isLoading else {
            return
        }

        do {
            try addonManager.setEnabled(
                addon,
                enabled: !addon.isEnabled
            )

            addons = try addonManager.scan(
                installation: installation
            )
        } catch {
            showError(error)
        }
    }

    // MARK: - Delete

    private func requestDelete(_ addon: GameAddon) {
        addonToDelete = addon
        isDeleteConfirmationPresented = true
    }

    private func deleteAddon(_ addon: GameAddon) {
        guard !isLoading else {
            return
        }

        do {
            try fileManager.removeItem(
                at: addon.directoryURL
            )

            addons = try addonManager.scan(
                installation: installation
            )

            addonToDelete = nil
        } catch {
            showError(error)
        }
    }

    // MARK: - Finder

    private func revealAddon(_ addon: GameAddon) {
        NSWorkspace.shared.activateFileViewerSelecting([
            addon.directoryURL
        ])
    }

    // MARK: - Errors

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isErrorPresented = true
    }
}
