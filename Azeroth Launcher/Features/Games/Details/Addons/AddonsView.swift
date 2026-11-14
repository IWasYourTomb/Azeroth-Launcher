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
        VStack(alignment: .leading, spacing: 14) {
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Installed Addons")
                        .font(.system(size: 14, weight: .bold))

                    Text("\(addons.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("Manage installed game modifications")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {

                    Label(
                        "\(enabledCount) " + String(localized: "Enabled"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                    Label(
                        "\(disabledCount) " + String(localized: "Disabled"),
                        systemImage: "pause.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
                .font(.system(size: 9, weight: .medium))
                .padding(.top, 3)
            }

            Spacer()

            Button {
                isImporterPresented = true
            } label: {
                Label("Install Addon", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isLoading)

            Button {
                scanAddons()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
            .help("Refresh addons")
        }
    }

    private var addonsList: some View {
        VStack(spacing: 12) {
            searchField
            if filteredAddons.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(height: 140)
            } else {

                LazyVStack(spacing: 9) {

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
        HStack(spacing: 9) {

            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search addons...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 12))
        .padding(11)
        .background(.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var loadingView: some View {
        HStack(spacing: 12) {

            ProgressView()
                .controlSize(.small)

            Text("Scanning addons...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(25)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No addons found")
                .font(.system(size: 13, weight: .semibold))

            Text("Addons installed in Interface/AddOns will appear here.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                scanAddons()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 25))
                .foregroundStyle(.orange)

            Text("Unable to scan addons")
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                scanAddons()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func revealAddon(_ addon: GameAddon) {
        NSWorkspace.shared.activateFileViewerSelecting([
            addon.directoryURL
        ])
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isErrorPresented = true
    }
}
