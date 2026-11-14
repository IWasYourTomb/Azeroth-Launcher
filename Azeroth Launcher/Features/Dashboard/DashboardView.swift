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
            SidebarView(
                selectedSection: $selectedSection
            )

            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(width: 1)

            mainContent
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background(
            Color(nsColor: .windowBackgroundColor)
        )
        .sheet(isPresented: $isInstallationWizardPresented) {
            InstallationWizardView()
                .environment(\.locale, appLocale)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    switch selectedSection {
                    case .home:
                        HomeView {
                            selectedSection = .games
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSection.title)
                    .font(.system(size: 22, weight: .bold))

                Text(selectedSection.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedSection == .games {
                Button {
                    isInstallationWizardPresented = true
                } label: {
                    Label("Add Game", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }
}
