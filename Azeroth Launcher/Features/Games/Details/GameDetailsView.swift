//
//  GameDetailsView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct GameDetailsView: View {
    let installation: GameInstallation
    @Environment(\.locale) private var appLocale
    @State private var isRealmManagerPresented = false
    @State private var currentRealmAddress: String?
    @State private var savedRealms: [RealmServer] = []
    @State private var isLaunchSettingsPresented = false
    
    private let realmFileService = RealmListFileService()
    private let realmStore = RealmServerStore()
    
    private var currentRealm: RealmServer? {
        guard let currentRealmAddress else { return nil }
        
        return savedRealms.first {
            $0.address.caseInsensitiveCompare(currentRealmAddress) == .orderedSame
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    heroSection
                    configurationSection
                    launchSettingsSection
                    realmSection
                    addonsSection
                }
                .padding(28)
            }
        }
        .frame(minWidth: 850, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isLaunchSettingsPresented) {
            GameLaunchSettingsView(installation: installation)
                .environment(\.locale, appLocale)
        }
        .sheet(
            isPresented: $isRealmManagerPresented,
            onDismiss: loadCurrentRealm
        ) {
            RealmListView(installation: installation)
                .environment(\.locale, appLocale)
        }
        .onAppear {
            loadCurrentRealm()
        }
    }
    
    private var launchSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Launch Configuration",
                subtitle: "Configure how this game client starts",
                icon: "slider.horizontal.3"
            )

            Button {
                isLaunchSettingsPresented = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                        .frame(width: 42, height: 42)
                        .background(.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Launch Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Renderer, Wine, arguments and environment")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Label("Back to Games", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("GAME MANAGEMENT")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
    }
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Image(installation.edition.backgroundImageName)
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
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(alignment: .leading, spacing: 10) {
                Text("GAME CLIENT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.orange)
                
                Text(installation.edition.title)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                
                Text("Version \(installation.edition.version)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                
                HStack(spacing: 7) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Installed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(25)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Installation",
                subtitle: "Game client information",
                icon: "folder.fill"
            )
            
            infoRow(
                title: "Game directory",
                value: installation.installationPath.path,
                icon: "folder"
            )
            
            infoRow(
                title: "Wine Prefix",
                value: installation.prefixPath.path,
                icon: "shippingbox"
            )
        }
    }
    
    private var realmSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Realm Configuration",
                subtitle: "Manage your game server connection",
                icon: "server.rack"
            )
            
            HStack(spacing: 14) {
                Image(systemName: "network")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 5) {
                    Group {
                        if let currentRealm {
                            Text(currentRealm.name)
                        } else if currentRealmAddress != nil {
                            Text("Custom Realm")
                        } else {
                            Text("Not configured")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    
                    if let currentRealmAddress {
                        Text(currentRealmAddress)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(currentRealmAddress == nil ? .gray : .green)
                    .frame(width: 8, height: 8)
                
                Button {
                    isRealmManagerPresented = true
                } label: {
                    Label(
                        "Update Realm List",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var addonsSection: some View {
        AddonsView(installation: installation)
    }
    
    private func sectionHeader( _ title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func infoRow(title: LocalizedStringKey, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func loadCurrentRealm() {
        savedRealms = realmStore.load(for: installation.edition)
        do {
            currentRealmAddress = try realmFileService.readCurrentRealm(
                installationPath: installation.installationPath
            )
        } catch {
            currentRealmAddress = nil
            print("Failed to read current realm: \(error.localizedDescription)")
        }
    }
    
}
