import SwiftUI
import SwiftData

struct PlayersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.createdAt) private var players: [Player]
    @State private var showAddPlayer = false
    @State private var editingPlayer: Player?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("PLAYERS")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { showAddPlayer = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "#39FF14"))
                    }
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if players.isEmpty {
                    Spacer()
                    ContentUnavailableView("No Players", systemImage: "person.badge.plus",
                        description: Text("Tap + to add your golf crew"))
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(players) { player in
                            PlayerRow(player: player)
                                .listRowBackground(Color(hex: "#111111"))
                                .onTapGesture { editingPlayer = player }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(players[i]) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .sheet(isPresented: $showAddPlayer) { AddPlayerView() }
        .sheet(item: $editingPlayer) { player in EditPlayerView(player: player) }
    }
}

struct PlayerRow: View {
    let player: Player
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#39FF14").opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(player.name.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(hex: "#39FF14"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    Label("TM \(player.taxMan)", systemImage: "flag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                    if !player.venmoHandle.isEmpty {
                        Label("Venmo", systemImage: "creditcard.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                    if !player.cashappHandle.isEmpty {
                        Label("Cash App", systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.gray.opacity(0.4))
        }
        .padding(.vertical, 6)
    }
}

struct AddPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var taxMan = 90
    @State private var venmo = ""
    @State private var cashapp = ""

    var body: some View {
        PlayerFormView(
            title: "ADD PLAYER",
            name: $name, taxMan: $taxMan, venmo: $venmo, cashapp: $cashapp,
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty
        ) {
            let player = Player(name: name.trimmingCharacters(in: .whitespaces),
                                taxMan: taxMan, venmoHandle: venmo, cashappHandle: cashapp)
            modelContext.insert(player)
            dismiss()
        }
    }
}

struct EditPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player
    @State private var name: String
    @State private var taxMan: Int
    @State private var venmo: String
    @State private var cashapp: String

    init(player: Player) {
        self.player = player
        _name = State(initialValue: player.name)
        _taxMan = State(initialValue: player.taxMan)
        _venmo = State(initialValue: player.venmoHandle)
        _cashapp = State(initialValue: player.cashappHandle)
    }

    var body: some View {
        PlayerFormView(
            title: "EDIT PLAYER",
            name: $name, taxMan: $taxMan, venmo: $venmo, cashapp: $cashapp,
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty
        ) {
            player.name = name.trimmingCharacters(in: .whitespaces)
            player.taxMan = taxMan
            player.venmoHandle = venmo
            player.cashappHandle = cashapp
            dismiss()
        }
    }
}

struct PlayerFormView: View {
    let title: String
    @Binding var name: String
    @Binding var taxMan: Int
    @Binding var venmo: String
    @Binding var cashapp: String
    let canSave: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }.foregroundStyle(.gray)
                    Spacer()
                    Text(title).font(.system(size: 14, weight: .black)).foregroundStyle(.white).tracking(2)
                    Spacer()
                    Button("Save") { onSave() }
                        .foregroundStyle(canSave ? Color(hex: "#39FF14") : .gray)
                        .disabled(!canSave)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Form {
                    Section("PLAYER INFO") {
                        TextField("Name", text: $name)
                        Stepper("TaxMan: \(taxMan)", value: $taxMan, in: 60...120)
                    }
                    Section("PAYMENT HANDLES") {
                        TextField("Venmo @username", text: $venmo)
                            .textInputAutocapitalization(.never)
                        TextField("Cash App $cashtag", text: $cashapp)
                            .textInputAutocapitalization(.never)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
