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
                VStack(alignment: .leading, spacing: 27) {
                    editionSelector

                    folderSelector

                    if let errorMessage {
                        messageView(errorMessage, isError: true)
                    }

                    if let successMessage {
                        messageView(successMessage, isError: false)
                    }
                }
                .padding(28)
            }
            .scrollIndicators(.visible)

            footer
        }
        .frame(width: 660, height: 700)
        .background(LauncherTheme.background)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleFolderSelection
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 15) {
            Image(systemName: "plus.square.fill")
                .font(.system(size: 25))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 50, height: 50)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text("Add Game Client")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Add an existing World of Warcraft client")
                    .font(.system(size: 12))
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
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(LauncherTheme.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)
        }
    }

    // MARK: - Edition Selector

    private var editionSelector: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader(
                title: "GAME VERSION",
                subtitle: "Choose the World of Warcraft era you want to add.",
                icon: "gamecontroller.fill"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 13),
                    GridItem(.flexible(), spacing: 13)
                ],
                spacing: 13
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
            withAnimation(.easeInOut(duration: 0.18)) {
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
                    stops: [
                        .init(color: .black.opacity(0.02), location: 0),
                        .init(color: .black.opacity(0.15), location: 0.35),
                        .init(color: .black.opacity(0.88), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 5) {
                    Spacer()

                    Text(edition.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("Version \(edition.version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(14)

                VStack {
                    HStack {
                        Spacer()

                        Image(
                            systemName: isSelected
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .font(.system(size: 20))
                        .foregroundStyle(
                            isSelected
                                ? LauncherTheme.accent
                                : .white.opacity(0.75)
                        )
                        .background {
                            Circle()
                                .fill(.black.opacity(0.3))
                                .padding(-3)
                        }
                    }

                    Spacer()
                }
                .padding(13)

                if isSelected {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(LauncherTheme.accent.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 135)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        isSelected
                            ? LauncherTheme.accent
                            : LauncherTheme.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.015 : 1)
    }

    // MARK: - Folder Selector

    private var folderSelector: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader(
                title: "GAME DIRECTORY",
                subtitle: "Select the folder containing your game files.",
                icon: "folder.fill"
            )

            Button {
                isImporterPresented = true
            } label: {
                HStack(spacing: 15) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 23))
                        .foregroundStyle(LauncherTheme.accent)
                        .frame(width: 50, height: 50)
                        .background(LauncherTheme.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 6) {
                        if let selectedFolder {
                            Text(selectedFolder.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LauncherTheme.primaryText)
                                .lineLimit(1)

                            Text(selectedFolder.path)
                                .font(.system(size: 10))
                                .foregroundStyle(LauncherTheme.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Choose game folder")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LauncherTheme.primaryText)

                            Text("Select a folder containing Wow.exe")
                                .font(.system(size: 11))
                                .foregroundStyle(LauncherTheme.secondaryText)
                        }
                    }

                    Spacer(minLength: 5)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
                .padding(16)
                .background(LauncherTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(
                            selectedFolder == nil
                                ? LauncherTheme.separator
                                : LauncherTheme.accent.opacity(0.5),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)

            if selectedFolder != nil {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text("Game directory selected")
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.leading, 3)
            }
        }
    }

    // MARK: - Messages

    private func messageView(
        _ message: String,
        isError: Bool
    ) -> some View {
        HStack(spacing: 11) {
            Image(
                systemName: isError
                    ? "exclamationmark.circle.fill"
                    : "checkmark.circle.fill"
            )
            .font(.system(size: 17))

            Text(verbatim: message)
                .font(.system(size: 11, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .foregroundStyle(
            isError ? Color.red : Color.green
        )
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isError ? Color.red : Color.green).opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(
                    (isError ? Color.red : Color.green).opacity(0.2),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("READY TO ADD")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LauncherTheme.secondaryText)

                Text(selectedFolder == nil
                     ? "Select a game directory to continue."
                     : selectedEdition.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LauncherTheme.primaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)
            .disabled(isInspecting)

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
                    .font(.system(size: 12, weight: .semibold))
                }
                .frame(minWidth: 145)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(LauncherTheme.accent)
            .controlSize(.large)
            .disabled(!canInstall)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 17)
        .background(LauncherTheme.sidebar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)
        }
    }

    // MARK: - Components

    private func sectionHeader(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 38, height: 38)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(LauncherTheme.secondaryText)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LauncherTheme.primaryText)
            }

            Spacer()
        }
    }

    // MARK: - Folder Selection

    private func handleFolderSelection(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case .success(let urls):
            selectedFolder = urls.first
            errorMessage = nil
            successMessage = nil

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Installation

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
