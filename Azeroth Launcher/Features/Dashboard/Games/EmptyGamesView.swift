//
//  EmptyGamesView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct EmptyGamesView: View {
    let onAddGame: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
                .frame(width: 90, height: 90)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(spacing: 7) {
                Text("No games installed")
                    .font(.system(size: 20, weight: .bold))

                Text("Add a World of Warcraft client to your library to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Button(action: onAddGame) {
                Label("Add Game", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 350)
    }
}
