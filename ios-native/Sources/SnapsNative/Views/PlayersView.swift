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
                            .foregroundStyle(Color.snapsGreen)
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
                                .listRowBackground(Color.snapsSurface1)
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
                    .fill(Color.snapsGreen.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(player.name.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.snapsGreen)
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
                        .foregroundStyle(canSave ? Color.snapsGreen : .gray)
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

// MARK: - Quick Add Player Sheet (used from SetupView)

struct QuickAddPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, Int) -> Void

    @State private var name = ""
    @State private var handicap = 18
    @State private var venmo = ""
    @State private var cashapp = ""

    var body: some View {
        ZStack {
            Color.snapsBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.snapsBorder)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Header
                HStack {
                    Text("NEW PLAYER")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 16) {

                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NAME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.snapsTextMuted)
                                .tracking(2)
                            TextField("Player name", text: $name)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.snapsTextPrimary)
                                .padding(16)
                                .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.snapsBorder, lineWidth: 1))
                        }

                        // Handicap
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("HANDICAP")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.snapsTextMuted)
                                    .tracking(2)
                                Spacer()
                                Text("\(handicap)")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(Color.snapsGreen)
                            }
                            Slider(
                                value: Binding(get: { Double(handicap) }, set: { handicap = Int($0) }),
                                in: 0...54, step: 1
                            )
                            .tint(Color.snapsGreen)
                            HStack {
                                Text("Scratch")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.snapsTextMuted)
                                Spacer()
                                Text("54")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.snapsTextMuted)
                            }
                        }
                        .padding(16)
                        .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.snapsBorder, lineWidth: 1))

                        // Optional: Venmo / CashApp
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PAYMENT (OPTIONAL)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.snapsTextMuted)
                                .tracking(2)
                            TextField("Venmo @username", text: $venmo)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.snapsTextPrimary)
                                .autocapitalization(.none)
                                .padding(14)
                                .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.snapsBorder, lineWidth: 1))
                            TextField("Cash App $cashtag", text: $cashapp)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.snapsTextPrimary)
                                .autocapitalization(.none)
                                .padding(14)
                                .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.snapsBorder, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }

                // Add button
                Button {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onAdd(name.trimmingCharacters(in: .whitespaces), handicap)
                    dismiss()
                } label: {
                    Text("Add to Round →")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.snapsGreen.opacity(0.4)
                                : Color.snapsGreen,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .buttonStyle(SnapsButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}
