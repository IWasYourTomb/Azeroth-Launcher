//
//  AddRealmView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct AddRealmView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var address: String

    let initialServer: RealmServer?
    let onSave: (RealmServer) -> Void

    init(server: RealmServer? = nil, onSave: @escaping (RealmServer) -> Void) {
        self.initialServer = server
        self.onSave = onSave

        _name = State(initialValue: server?.name ?? "")
        _address = State(initialValue: server?.address ?? "")
    }

    private var isEditing: Bool {
        initialServer != nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 18) {
                inputField(
                    title: "SERVER NAME",
                    placeholder: "e.g. My Favorite Realm",
                    icon: "server.rack",
                    text: $name
                )

                inputField(
                    title: "SERVER ADDRESS",
                    placeholder: "e.g. logon.example.com",
                    icon: "network",
                    text: $address
                )
            }

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: save) {
                    Label(
                        isEditing ? "Save Changes" : "Add Realm",
                        systemImage: isEditing ? "checkmark" : "plus"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(LauncherTheme.accent)
                .controlSize(.large)
                .disabled(!isValid)
            }
        }
        .padding(26)
        .frame(width: 460)
        .background(LauncherTheme.background)
    }

    private var header: some View {
        HStack(spacing: 15) {
            Image(systemName: isEditing ? "server.rack" : "plus.circle.fill")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 54, height: 54)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text(isEditing ? "Edit Realm" : "Add Realm")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(
                    isEditing
                        ? "Update your game server details."
                        : "Add a game server to your collection."
                )
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
                    .frame(width: 30, height: 30)
                    .background(LauncherTheme.elevatedSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func inputField(
        title: LocalizedStringKey,
        placeholder: String,
        icon: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(LauncherTheme.secondaryText)

            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(LauncherTheme.accent)
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(LauncherTheme.primaryText)
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(LauncherTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(LauncherTheme.separator, lineWidth: 1)
            }
        }
    }

    private func save() {
        let server = RealmServer(
            id: initialServer?.id ?? UUID(),
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            address: address.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )

        onSave(server)
    }
}
