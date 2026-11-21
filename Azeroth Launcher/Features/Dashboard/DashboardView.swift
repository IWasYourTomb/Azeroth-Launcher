//
//  DashboardView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct DashboardView: View {
    @Environment(\.locale) private var appLocale

    @State private var selectedSection: DashboardSection = .home
    @State private var isInstallationWizardPresented = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedSection: $selectedSection)

            mainContent
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background(LauncherTheme.background)
        .sheet(isPresented: $isInstallationWizardPresented) {
            InstallationWizardView()
                .environment(\.locale, appLocale)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)

            ScrollView {
                Group {
                    switch selectedSection {
                    case .home:
                        HomeView {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedSection = .games
                            }
                        }

                    case .games:
                        GamesView {
                            isInstallationWizardPresented = true
                        }

                    case .settings:
                        SettingsView()
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(selectedSection.title)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(selectedSection.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            if selectedSection == .games {
                Button {
                    isInstallationWizardPresented = true
                } label: {
                    Label("Add Game", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LauncherTheme.background)
                        .padding(.horizontal, 17)
                        .frame(height: 38)
                        .background {
                            LinearGradient(
                                colors: [
                                    LauncherTheme.accent,
                                    LauncherTheme.accent.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)

                Text("AZEROTH")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(LauncherTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(LauncherTheme.surface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(LauncherTheme.separator, lineWidth: 1)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(LauncherTheme.background)
    }
}
