//
//  SidebarView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedSection: DashboardSection

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            logo
            menu
            Spacer()
            footer
        }
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.45)
        )
    }

    private var logo: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AZEROTH")
                .font(.system(size: 24, weight: .black))
                .tracking(1)

            Text("LAUNCHER")
                .font(.system(size: 10, weight: .bold))
                .tracking(4)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MENU")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.bottom, 5)

            ForEach(DashboardSection.allCases) { section in
                sidebarButton(section)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AZEROTH LAUNCHER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            Text("Version 1.0.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
    }

    private func sidebarButton(_ section: DashboardSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 15))
                    .frame(width: 20)

                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(
                isSelected ? .white : .secondary
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.orange.opacity(0.18))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange)
                                .frame(width: 3)
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}
