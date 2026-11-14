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
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isEditing ? "EDIT REALM" : "ADD REALM")
                        .font(.system(size: 20, weight: .black))
                        .tracking(1)

                    Text(
                        isEditing
                            ? "Update your game server details."
                            : "Add a game server to your collection."
                    )
                    .font(.system(size: 13))
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

            VStack(alignment: .leading, spacing: 8) {
                Text("SERVER NAME")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                TextField("e.g. My Favorite Realm", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SERVER ADDRESS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                TextField("e.g. logon.example.com", text: $address)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
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
                } label: {
                    Label(
                        isEditing ? "Save Changes" : "Add Realm",
                        systemImage: isEditing ? "checkmark" : "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
