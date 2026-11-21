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

    @State private var selectedFolder: URL?
    @State private var detectedClient: GameClientInspection?

    @State private var isImporterPresented = false
    @State private var isDropTargeted = false
    @State private var isInspecting = false
    @State private var isInstalling = false

    @State private var errorMessage: String?
    @State private var inspectionID = UUID()

    private let installationService = GameInstallationService()

    private var canInstall: Bool {
        detectedClient != nil &&
        !isInspecting &&
        !isInstalling
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    folderSelector

                    detectionSection

                    if let errorMessage {
                        messageView(
                            errorMessage,
                            isError: true
                        )
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

    private var folderSelector: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader(
                title: "GAME DIRECTORY",
                subtitle: "Drop your game folder or select it manually.",
                icon: "folder.fill"
            )

            Button {
                guard !isInspecting, !isInstalling else {
                    return
                }

                isImporterPresented = true
            } label: {
                VStack(spacing: 15) {
                    Image(
                        systemName: isDropTargeted
                            ? "folder.badge.plus"
                            : "arrow.down.doc.fill"
                    )
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(LauncherTheme.accent)
                    .frame(width: 70, height: 70)
                    .background(LauncherTheme.accentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(spacing: 6) {
                        Text(
                            isDropTargeted
                                ? "Drop game folder here"
                                : "Drag & Drop your game folder"
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LauncherTheme.primaryText)

                        Text("Or click here to browse your files")
                            .font(.system(size: 11))
                            .foregroundStyle(LauncherTheme.secondaryText)
                    }

                    if let selectedFolder {
                        HStack(spacing: 7) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(LauncherTheme.accent)

                            Text(selectedFolder.lastPathComponent)
                                .foregroundStyle(LauncherTheme.primaryText)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LauncherTheme.elevatedSurface)
                        .clipShape(Capsule())
                    } else {
                        Text("WOW.EXE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(LauncherTheme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(LauncherTheme.elevatedSurface)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(
                    isDropTargeted
                        ? LauncherTheme.accentBackground
                        : LauncherTheme.surface
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isDropTargeted
                                ? LauncherTheme.accent
                                : LauncherTheme.separator,
                            style: StrokeStyle(
                                lineWidth: isDropTargeted ? 2 : 1,
                                dash: [7, 5]
                            )
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(isInspecting || isInstalling)
            .onDrop(
                of: [UTType.fileURL],
                isTargeted: $isDropTargeted,
                perform: handleDrop
            )
            .animation(
                .easeInOut(duration: 0.18),
                value: isDropTargeted
            )
        }
    }


    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader(
                title: "CLIENT DETECTION",
                subtitle: "The launcher automatically identifies your game.",
                icon: "sparkles"
            )

            if isInspecting {
                detectionProgress
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let detectedClient {
                detectedClientCard(detectedClient)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                detectionPlaceholder
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isInspecting)
        .animation(
            .easeInOut(duration: 0.2),
            value: detectedClient?.version.build
        )
    }

    private var detectionPlaceholder: some View {
        HStack(spacing: 13) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21))
                .foregroundStyle(LauncherTheme.secondaryText)

            VStack(alignment: .leading, spacing: 5) {
                Text("Waiting for game directory")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Select or drop a folder to identify the installed expansion.")
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(
                    LauncherTheme.separator,
                    lineWidth: 1
                )
        }
    }

    private var detectionProgress: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
                .tint(LauncherTheme.accent)

            VStack(alignment: .leading, spacing: 5) {
                Text("Analyzing game client...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Detecting version and validating game files.")
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func detectedClientCard(_ client: GameClientInspection) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    Image(client.edition.backgroundImageName)
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
                        .init(
                            color: .black.opacity(0.02),
                            location: 0
                        ),
                        .init(
                            color: .black.opacity(0.15),
                            location: 0.4
                        ),
                        .init(
                            color: .black.opacity(0.9),
                            location: 1
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text("GAME CLIENT DETECTED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.8))

                    Text(client.edition.title)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(
                            color: .black.opacity(0.5),
                            radius: 5,
                            y: 2
                        )

                    Text("Version \(client.version.versionString)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(20)

                VStack {
                    HStack {
                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")

                            Text("VERIFIED")
                                .tracking(1)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.85))
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(15)
            }
            .frame(height: 185)
            .clipped()

            HStack(spacing: 0) {
                detectionValue(
                    title: "BUILD",
                    value: "\(client.version.build)"
                )

                Spacer()

                detectionValue(
                    title: "MPQ ARCHIVES",
                    value: "\(client.mpqCount)"
                )

                Spacer()

                detectionValue(
                    title: "STATUS",
                    value: "Ready"
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(LauncherTheme.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    Color.green.opacity(0.35),
                    lineWidth: 1
                )
        }
    }

    private func detectionValue(title: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(LauncherTheme.secondaryText)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LauncherTheme.primaryText)
        }
    }

    private func messageView(_ message: String, isError: Bool) -> some View {
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
        .foregroundStyle(isError ? Color.red : Color.green)
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

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("READY TO ADD")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LauncherTheme.secondaryText)

                Group {
                    if let edition = detectedClient?.edition.title {
                       Text(edition)
                    } else {
                       Text("Select a game directory to continue.")
                     }
                    }
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
            .disabled(isInspecting || isInstalling)

            Button {
                registerInstallation()
            } label: {
                HStack(spacing: 9) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }

                    Text(
                        isInstalling
                            ? "Adding Game..."
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

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folder = urls.first else {
                return
            }

            selectFolder(folder)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isInspecting,
              !isInstalling,
              let provider = providers.first(where: {
                  $0.hasItemConformingToTypeIdentifier(
                      UTType.fileURL.identifier
                  )
              })
        else {
            return false
        }

        provider.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier,
            options: nil
        ) { item, error in
            let droppedURL: URL?

            if let url = item as? URL {
                droppedURL = url
            } else if let url = item as? NSURL {
                droppedURL = url as URL
            } else if let data = item as? Data {
                droppedURL = URL(
                    dataRepresentation: data,
                    relativeTo: nil
                )
            } else {
                droppedURL = nil
            }

            Task { @MainActor in
                guard let droppedURL else {
                    errorMessage = error?.localizedDescription
                        ?? "Unable to read the dropped file."

                    return
                }

                selectFolder(droppedURL)
            }
        }

        return true
    }

    private func selectFolder(_ folder: URL) {
        guard !isInstalling else {
            return
        }

        inspectionID = UUID()

        selectedFolder = folder
        detectedClient = nil
        errorMessage = nil

        inspectFolder(folder)
    }

    private func inspectFolder(_ folder: URL) {
        let requestID = inspectionID

        isInspecting = true
        detectedClient = nil
        errorMessage = nil

        Task { @MainActor in
            let hasAccess = folder.startAccessingSecurityScopedResource()

            defer {
                if hasAccess {
                    folder.stopAccessingSecurityScopedResource()
                }

                if inspectionID == requestID {
                    isInspecting = false
                }
            }

            do {
                let inspection = try installationService.inspect(
                    at: folder
                )

                guard inspectionID == requestID else {
                    return
                }

                detectedClient = inspection

                print("""
                [InstallationWizard] Client detected
                Edition: \(inspection.edition.title)
                Version: \(inspection.version.versionString)
                Build: \(inspection.version.build)
                MPQ: \(inspection.mpqCount)
                """)

            } catch {
                guard inspectionID == requestID else {
                    return
                }

                errorMessage = error.localizedDescription
            }
        }
    }

    private func registerInstallation() {
        guard let folder = selectedFolder,
              detectedClient != nil,
              !isInstalling
        else {
            return
        }

        isInstalling = true
        errorMessage = nil

        Task { @MainActor in
            let hasAccess = folder.startAccessingSecurityScopedResource()

            defer {
                if hasAccess {
                    folder.stopAccessingSecurityScopedResource()
                }

                isInstalling = false
            }

            do {
                // Повторная проверка перед регистрацией.
                // Не полагаемся на ранее сохранённый результат.
                let inspection = try installationService.inspect(
                    at: folder
                )

                let prefixURL = FileManager.default
                    .urls(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask
                    )[0]
                    .appendingPathComponent(
                        "AzerothLauncher/Prefixes/\(inspection.edition.rawValue)",
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

                print(
                    "[InstallationWizard] Added \(inspection.edition.title)"
                )

                dismiss()

            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
