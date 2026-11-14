//
//  InstallationWizardView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct InstallationWizardView: View {
    @Environment(GameManager.self) private var gameManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEdition: GameEdition = .wrath
    @State private var selectedFolder: URL?
    @State private var isImporterPresented = false
    @State private var isInspecting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let installationService = GameInstallationService()
    private let clientValidator = GameClientValidator()

    private var canInstall: Bool {
        selectedFolder != nil && !isInspecting
    }

    var body: some View {
        VStack(spacing: 0) {
 
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    editionSelector
                    folderSelector
                    if let errorMessage {
                        messageView(
                            errorMessage,
                            isError: true
                        )
                    }

                    if let successMessage {
                        messageView(
                            successMessage,
                            isError: false
                        )
                    }
                }
                .padding(28)
            }
            footer
        }
        .frame(width: 600, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleFolderSelection
        )
    }

    private var header: some View {
        HStack(spacing: 15) {
            Image(systemName: "plus.square.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 5) {
                Text("Add Game Client")
                    .font(.system(size: 23, weight: .bold))
                Text("Add an existing World of Warcraft client")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(.ultraThinMaterial)
    }

    private var editionSelector: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "GAME VERSION",
                subtitle: "Choose your edition",
                icon: "gamecontroller.fill"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                ForEach(GameEdition.allCases) { edition in
                    editionCard(edition)
                }
            }
        }
    }

    private func editionCard(_ edition: GameEdition) -> some View {
        let isSelected = selectedEdition == edition
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedEdition = edition
                errorMessage = nil
                successMessage = nil
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    Image(edition.backgroundImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                }
                LinearGradient(
                    colors: [
                        .black.opacity(0.05),
                        .black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 5) {
                    Spacer()
                    Text(edition.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("Version \(edition.version)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(13)
                VStack {
                    HStack {
                        Spacer()
                        Image(
                            systemName: isSelected
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .font(.system(size: 19))
                        .foregroundStyle(
                            isSelected ? .orange : .white.opacity(0.7)
                        )
                    }

                    Spacer()
                }
                .padding(12)
            }
            .frame(height: 115)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? Color.orange
                            : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var folderSelector: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "GAME DIRECTORY",
                subtitle: "Select the folder containing your game files",
                icon: "folder.fill"
            )
            Button {
                isImporterPresented = true
            } label: {
                HStack(spacing: 15) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 25))
                        .foregroundStyle(.orange)
                        .frame(width: 48, height: 48)
                        .background(.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 5) {
                        if let selectedFolder {
                            Text(selectedFolder.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        } else {
                            Text("Choose game folder")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        if let selectedFolder {
                            Text(selectedFolder.path)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Select a folder containing Wow.exe")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }
    private func messageView( _ message: String, isError: Bool) -> some View {
        HStack(spacing: 12) {
            Image(
                systemName: isError
                    ? "exclamationmark.circle.fill"
                    : "checkmark.circle.fill"
            )
            .font(.system(size: 17))

            if isError {
                Text(verbatim: message)
                    .font(.system(size: 12))
            } else {
                Text(LocalizedStringKey(message))
                    .font(.system(size: 12))
            }

            Spacer()
        }
        .foregroundStyle(isError ? .red : .green)
        .padding(14)
        .background(
            (isError ? Color.red : Color.green).opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isInspecting)
            Spacer()
            Button {
                registerInstallation()
            } label: {
                HStack(spacing: 9) {
                    if isInspecting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }

                    Text(
                        isInspecting
                            ? "Validating client..."
                            : "Add Game"
                    )
                    .fontWeight(.semibold)
                }
                .frame(minWidth: 140)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!canInstall)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
    }

    private func sectionHeader( title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }

    private func handleFolderSelection( _ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFolder = urls.first
            errorMessage = nil
            successMessage = nil

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func registerInstallation() {
        guard let folder = selectedFolder else {
            return
        }

        isInspecting = true
        errorMessage = nil
        successMessage = nil

        Task { @MainActor in
            let hasAccess = folder.startAccessingSecurityScopedResource()
            guard hasAccess else {
                isInspecting = false
                errorMessage = "Unable to access the selected game directory."
                return
            }
            defer {
                if hasAccess {
                    folder.stopAccessingSecurityScopedResource()
                }
                isInspecting = false
            }
            do {
                let inspection = try installationService.inspect(
                    at: folder,
                    edition: selectedEdition
                )
                let validation = try clientValidator.validate(
                    at: inspection.installationURL,
                    expectedEdition: selectedEdition
                )
                print(validation.summary)
                let prefixURL = FileManager.default
                    .urls(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask
                    )[0]
                    .appendingPathComponent(
                        "AzerothLauncher/Prefixes/\(selectedEdition.rawValue)",
                        isDirectory: true
                    )

                let bookmarkData = try folder.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                let installation = GameInstallation(
                    edition: inspection.edition,
                    installationPath: inspection.installationURL,
                    prefixPath: prefixURL,
                    bookmarkData: bookmarkData,
                    isInstalled: true
                )

                gameManager.add(installation)
                successMessage = "Game client successfully added."
                dismiss()

            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
