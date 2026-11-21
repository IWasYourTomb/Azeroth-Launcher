//
//  SidebarView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedSection: DashboardSection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var selectionAnimation

    @State private var isLogoAnimating = false
    @State private var hasAppeared = false
    @State private var hoveredSection: DashboardSection?
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            logo

            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .padding(.bottom, 25)

            menu

            Spacer()

            footer
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background {
            sidebarBackground
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(width: 1)
        }
        .onAppear {
            hasAppeared = true

            guard !reduceMotion else {
                return
            }

            withAnimation(
                .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
            ) {
                isLogoAnimating = true
            }
        }
    }

    private var sidebarBackground: some View {
        ZStack(alignment: .top) {
            LauncherTheme.sidebar

            Circle()
                .fill(LauncherTheme.accent.opacity(0.10))
                .frame(width: 190, height: 190)
                .blur(radius: 85)
                .offset(x: -75, y: 65)

            Circle()
                .fill(LauncherTheme.accentSecondary.opacity(0.08))
                .frame(width: 160, height: 160)
                .blur(radius: 80)
                .offset(x: 120, y: 360)

            ArcaneParticleView(
                particleCount: 24,
                intensity: 0.8
            )
        }
    }

    private var logo: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(LauncherTheme.accentBackground)
                    .frame(width: 43, height: 43)
                    .blur(radius: 5)

                Circle()
                    .stroke(
                        LauncherTheme.accent.opacity(0.25),
                        lineWidth: 1
                    )
                    .frame(width: 43, height: 43)

                Circle()
                    .trim(from: 0.05, to: 0.35)
                    .stroke(
                        LauncherTheme.accent.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: 1.2,
                            lineCap: .round
                        )
                    )
                    .frame(width: 43, height: 43)
                    .rotationEffect(
                        .degrees(isLogoAnimating ? 360 : 0)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(LauncherTheme.accent)
                    .shadow(
                        color: LauncherTheme.accent.opacity(0.6),
                        radius: isLogoAnimating ? 13 : 5
                    )
                    .scaleEffect(isLogoAnimating ? 1.08 : 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("AZEROTH")
                    .font(.system(size: 17, weight: .black))
                    .tracking(1.8)
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("LAUNCHER")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(3.5)
                    .foregroundStyle(LauncherTheme.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
    }


    private var menu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NAVIGATION")
                .font(.system(size: 9, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(
                    LauncherTheme.secondaryText.opacity(0.7)
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .opacity(hasAppeared ? 1 : 0)

            ForEach(
                Array(DashboardSection.allCases.enumerated()),
                id: \.element.id
            ) { item in
                sidebarButton(
                    item.element,
                    index: item.offset
                )
            }
        }
    }

    private func sidebarButton(
        _ section: DashboardSection,
        index: Int
    ) -> some View {
        let isSelected = selectedSection == section
        let isHovered = hoveredSection == section

        return Button {
            withAnimation(
                .spring(response: 0.4, dampingFraction: 0.8)
            ) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 21)
                    .symbolEffect(
                        .bounce,
                        value: isSelected
                    )

                Text(section.title)
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                if isSelected {
                    Circle()
                        .fill(LauncherTheme.accent)
                        .frame(width: 5, height: 5)
                        .shadow(
                            color: LauncherTheme.accent.opacity(0.8),
                            radius: 6
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(
                isSelected
                    ? LauncherTheme.accent
                    : LauncherTheme.secondaryText
            )
            .padding(.horizontal, 14)
            .frame(height: 45)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LauncherTheme.accentBackground)
                        .matchedGeometryEffect(
                            id: "selectedSection",
                            in: selectionAnimation
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LauncherTheme.accent.opacity(0.2),
                                    lineWidth: 1
                                )
                        }
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LauncherTheme.accent)
                                .frame(width: 3, height: 22)
                                .shadow(
                                    color: LauncherTheme.accent.opacity(0.5),
                                    radius: 6
                                )
                        }
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LauncherTheme.surface.opacity(0.65))
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(isHovered && !isSelected ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : -14)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.45, dampingFraction: 0.8)
                    .delay(Double(index) * 0.07),
            value: hasAppeared
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                hoveredSection = hovering ? section : nil
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)

            HStack(spacing: 9) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(LauncherTheme.accent)
                    .shadow(
                        color: LauncherTheme.accent.opacity(0.4),
                        radius: 5
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("AZEROTH LAUNCHER")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text("Version \(appVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }
}
