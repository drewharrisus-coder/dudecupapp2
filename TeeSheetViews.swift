//
//  TeeSheetViews.swift
//  The Rug
//
//  Contains:
//    • TeeSheetBuilderView  — Commish tool (linked from CommishDashboard)
//    • MyTeeTimeCard        — Player home screen card
//    • ScheduleTeeTimeBar   — Compact strip shown on Schedule tab
//

import SwiftUI

// MARK: - Commish: Tee Sheet Builder

struct TeeSheetBuilderView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var roundNumber: Int = 1
    @State private var firstTeeTime: Date = {
        // Default to 8 AM tomorrow
        var comps = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        comps.hour = 8; comps.minute = 0; comps.second = 0
        return Calendar.current.date(from: comps)?.addingTimeInterval(86400) ?? Date()
    }()
    @State private var intervalMinutes: Int = 10
    @State private var workingSheet: TeeSheet? = nil
    @State private var selectedPlayerId: UUID? = nil   // for tap-to-move
    @State private var isSaving = false
    @State private var isPublishing = false
    @State private var showPublishConfirm = false
    @State private var showGenerateConfirm = false

    let intervalOptions = [8, 10, 12]

    var isPublished: Bool { workingSheet?.isPublished ?? false }
    var hasGroups: Bool { !(workingSheet?.groups.isEmpty ?? true) }

    var unassigned: [Player] {
        guard let sheet = workingSheet else { return [] }
        return manager.unassignedPlayers(for: sheet)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    builderHeader
                    settingsPanel
                    if let sheet = workingSheet {
                        groupsPanel(sheet: sheet)
                        if !unassigned.isEmpty {
                            unassignedPanel
                        }
                        actionBar(sheet: sheet)
                    } else {
                        emptyState
                    }
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { loadExisting() }
        .alert("Re-generate Pairings?", isPresented: $showGenerateConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Generate", role: .destructive) { generate() }
        } message: {
            Text("This will overwrite the current groups. Any manual edits will be lost.")
        }
        .alert("Publish Tee Times?", isPresented: $showPublishConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Publish & Notify") {
                isPublishing = true
                Task {
                    await manager.publishTeeSheet(roundNumber: roundNumber)
                    await MainActor.run {
                        isPublishing = false
                        if let i = manager.teeSheets.firstIndex(where: { $0.roundNumber == roundNumber }) {
                            workingSheet = manager.teeSheets[i]
                        }
                    }
                }
            }
        } message: {
            Text("This pushes tee times live to all players and sends an announcement. You can still make edits after publishing.")
        }
    }

    // ── Header ─────────────────────────────────────────────────────────────

    var builderHeader: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color("DudeCupGreen").opacity(0.15), Color.clear],
                           center: .top, startRadius: 0, endRadius: 220)
            VStack(spacing: 6) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    if isPublished {
                        Text("PUBLISHED")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color("DudeCupGreen"))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("TEE SHEET")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(Color("DudeCupGreen"))

                Text("BUILDER")
                    .font(.system(size: 48, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(.white)
                    .padding(.bottom, 20)
            }
        }
    }

    // ── Settings Panel ─────────────────────────────────────────────────────

    var settingsPanel: some View {
        VStack(spacing: 0) {
            sectionLabel("SETTINGS")

            VStack(spacing: 0) {
                // Round picker
                HStack {
                    Text("Round")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $roundNumber) {
                        ForEach(1...4, id: \.self) { n in
                            Text("Round \(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color("DudeCupGreen"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .onChange(of: roundNumber) { _, _ in loadExisting() }

                divider

                // First tee time
                HStack {
                    Text("First Tee Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    DatePicker("", selection: $firstTeeTime,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .tint(Color("DudeCupGreen"))
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                divider

                // Interval
                HStack {
                    Text("Interval")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $intervalMinutes) {
                        ForEach(intervalOptions, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    // ── Groups Panel ───────────────────────────────────────────────────────

    func groupsPanel(sheet: TeeSheet) -> some View {
        VStack(spacing: 0) {
            HStack {
                sectionLabel("GROUPS — \(sheet.groups.count) TEES")
                Spacer()
                Button {
                    hasGroups ? (showGenerateConfirm = true) : generate()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("AUTO")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(2)
                    }
                    .foregroundStyle(Color("DudeCupGreen"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color("DudeCupGreen").opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.trailing, 16)
                .padding(.top, 24)
            }

            if selectedPlayerId != nil {
                movingBanner
            }

            VStack(spacing: 10) {
                ForEach(Array(sheet.groups.enumerated()), id: \.element.id) { idx, group in
                    groupCard(group: group, index: idx)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    var movingBanner: some View {
        let name = manager.players.first(where: { $0.id == selectedPlayerId })?.name ?? "Player"
        return HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 12, weight: .bold))
            Text("TAP A SLOT TO MOVE \(name.uppercased())")
                .font(.system(size: 10, weight: .heavy))
                .tracking(2)
            Spacer()
            Button("CANCEL") { selectedPlayerId = nil }
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white.opacity(0.4))
        }
        .foregroundStyle(Color("DudeCupGreen"))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color("DudeCupGreen").opacity(0.1))
    }

    func groupCard(group: TeeSheetGroup, index: Int) -> some View {
        VStack(spacing: 0) {
            // Group header
            HStack {
                Text("GROUP \(index + 1)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(Color("DudeCupGreen"))
                Spacer()
                Text(group.teeTime, style: .time)
                    .font(.system(size: 16, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(white: 0.1))

            // Player slots
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { slotIdx in
                    playerSlot(group: group, groupIndex: index, slotIndex: slotIdx)
                    if slotIdx < 3 {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    func playerSlot(group: TeeSheetGroup, groupIndex: Int, slotIndex: Int) -> some View {
        let playerId: UUID? = slotIndex < group.playerIds.count ? group.playerIds[slotIndex] : nil
        let player = playerId.flatMap { pid in manager.players.first(where: { $0.id == pid }) }
        let isSelected = playerId != nil && selectedPlayerId == playerId
        let isMoving = selectedPlayerId != nil

        return Button {
            handleSlotTap(group: group, groupIndex: groupIndex, slotIndex: slotIndex, playerId: playerId)
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color("DudeCupGreen")
                              : player != nil
                                  ? Color(white: 0.15)
                                  : Color(white: 0.1))
                        .frame(width: 34, height: 34)
                    if let p = player {
                        Text(initials(p.name))
                            .font(.system(size: 12, weight: .black))
                            .fontWidth(.compressed)
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                    } else {
                        Image(systemName: isMoving ? "plus" : "person.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isMoving
                                             ? Color("DudeCupGreen").opacity(0.7)
                                             : .white.opacity(0.12))
                    }
                }

                if let p = player {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isSelected ? Color("DudeCupGreen") : .white)
                        Text("HCP \(p.handicap)")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.25))
                    }
                } else {
                    Text(isMoving ? "MOVE HERE" : "EMPTY SLOT")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(isMoving
                                         ? Color("DudeCupGreen").opacity(0.6)
                                         : .white.opacity(0.12))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color("DudeCupGreen"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(isSelected ? Color("DudeCupGreen").opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(isPublished)
    }

    // ── Unassigned Panel ───────────────────────────────────────────────────

    var unassignedPanel: some View {
        VStack(spacing: 0) {
            sectionLabel("UNASSIGNED — \(unassigned.count)")

            VStack(spacing: 0) {
                ForEach(Array(unassigned.enumerated()), id: \.element.id) { idx, player in
                    Button {
                        if selectedPlayerId == player.id {
                            selectedPlayerId = nil
                        } else {
                            selectedPlayerId = player.id
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(selectedPlayerId == player.id
                                          ? Color("DudeCupGreen")
                                          : Color(white: 0.15))
                                    .frame(width: 34, height: 34)
                                Text(initials(player.name))
                                    .font(.system(size: 12, weight: .black))
                                    .fontWidth(.compressed)
                                    .foregroundStyle(selectedPlayerId == player.id ? .black : .white.opacity(0.7))
                            }
                            Text(player.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("HCP \(player.handicap)")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(selectedPlayerId == player.id
                                    ? Color("DudeCupGreen").opacity(0.06) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPublished)

                    if idx < unassigned.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // ── Action Bar ─────────────────────────────────────────────────────────

    func actionBar(sheet: TeeSheet) -> some View {
        VStack(spacing: 10) {
            // Save draft
            if !isPublished {
                Button {
                    isSaving = true
                    Task {
                        await manager.saveTeeSheet(sheet)
                        await MainActor.run { isSaving = false }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text(isSaving ? "SAVING…" : "SAVE DRAFT")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSaving || isPublishing)
            }

            // Publish
            Button {
                showPublishConfirm = true
            } label: {
                HStack(spacing: 8) {
                    if isPublishing {
                        ProgressView().tint(.black).scaleEffect(0.8)
                    } else {
                        Image(systemName: isPublished
                              ? "checkmark.seal.fill"
                              : "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isPublishing ? "PUBLISHING…"
                         : isPublished ? "REPUBLISH & NOTIFY"
                         : "PUBLISH & NOTIFY ALL")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("DudeCupGreen"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSaving || isPublishing || !hasGroups || !unassigned.isEmpty)
            .opacity(!hasGroups || !unassigned.isEmpty ? 0.4 : 1.0)

            if !unassigned.isEmpty {
                Text("Assign all \(unassigned.count) unassigned players before publishing")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    // ── Empty State ────────────────────────────────────────────────────────

    var emptyState: some View {
        VStack(spacing: 16) {
            Text("⛳️").font(.system(size: 56))
            Text("NO TEE SHEET YET")
                .font(.system(size: 18, weight: .black))
                .fontWidth(.compressed)
                .tracking(3)
                .foregroundStyle(.white.opacity(0.3))
            Text("Use AUTO to generate pairings or build manually.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.2))
                .multilineTextAlignment(.center)

            Button {
                generate()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dice.fill")
                    Text("AUTO-GENERATE ROUND \(roundNumber)")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(Color("DudeCupGreen"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }

    // ── Logic ──────────────────────────────────────────────────────────────

    func loadExisting() {
        workingSheet = manager.teeSheet(for: roundNumber)
        if let sheet = workingSheet {
            firstTeeTime = sheet.firstTeeTime
            intervalMinutes = sheet.intervalMinutes
        }
    }

    func generate() {
        var sheet = manager.autoGeneratePairings(
            roundNumber: roundNumber,
            firstTeeTime: firstTeeTime,
            intervalMinutes: intervalMinutes
        )
        sheet.firstTeeTime = firstTeeTime
        sheet.intervalMinutes = intervalMinutes
        sheet.recalculateTimes()
        workingSheet = sheet
        selectedPlayerId = nil

        // Persist to local manager + Firebase
        if let i = manager.teeSheets.firstIndex(where: { $0.roundNumber == roundNumber }) {
            manager.teeSheets[i] = sheet
        } else {
            manager.teeSheets.append(sheet)
        }
        Task { await manager.saveTeeSheet(sheet) }
    }

    func handleSlotTap(group: TeeSheetGroup, groupIndex: Int, slotIndex: Int, playerId: UUID?) {
        guard var sheet = workingSheet, !isPublished else { return }

        if let moving = selectedPlayerId {
            // Move the selected player into this slot
            movePlayer(moving, toGroup: groupIndex, toSlot: slotIndex, in: &sheet)
            selectedPlayerId = nil
        } else if let pid = playerId {
            // Pick up this player to move
            selectedPlayerId = pid
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func movePlayer(_ playerId: UUID, toGroup: Int, toSlot: Int, in sheet: inout TeeSheet) {
        // Find where the player currently lives
        var fromGroup: Int? = nil
        var fromSlot: Int? = nil
        for (gi, group) in sheet.groups.enumerated() {
            if let si = group.playerIds.firstIndex(of: playerId) {
                fromGroup = gi; fromSlot = si; break
            }
        }
        // Also check unassigned (player not yet in any group)
        let isUnassigned = fromGroup == nil

        let targetGroup = toGroup
        let targetHasPlayer = toSlot < sheet.groups[targetGroup].playerIds.count

        if targetHasPlayer {
            let displacedId = sheet.groups[targetGroup].playerIds[toSlot]
            // Swap
            sheet.groups[targetGroup].playerIds[toSlot] = playerId
            if let fg = fromGroup, let fs = fromSlot {
                sheet.groups[fg].playerIds[fs] = displacedId
            }
        } else {
            // Place in empty slot
            if sheet.groups[targetGroup].playerIds.count <= toSlot {
                sheet.groups[targetGroup].playerIds.append(playerId)
            } else {
                sheet.groups[targetGroup].playerIds[toSlot] = playerId
            }
            // Remove from old location if it was in a group
            if let fg = fromGroup, let fs = fromSlot, !isUnassigned {
                sheet.groups[fg].playerIds.remove(at: fs)
            }
        }

        workingSheet = sheet
                if let i = manager.teeSheets.firstIndex(where: { $0.roundNumber == roundNumber }) {
                    manager.teeSheets[i] = sheet
                }
                let sheetToSave = sheet  // capture a local copy before Task
                Task { await manager.saveTeeSheet(sheetToSave) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // ── Shared Helpers ─────────────────────────────────────────────────────

    func initials(_ name: String) -> String {
        name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    var divider: some View {
        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16)
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .tracking(4)
            .foregroundStyle(Color("DudeCupGreen"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 10)
    }
}


// MARK: - Player: My Tee Time Card (Home Screen)

struct MyTeeTimeCard: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager

    var currentPlayer: Player? { authManager.currentPlayer }

    var activeSheet: TeeSheet? {
        manager.teeSheets
            .filter { $0.isPublished }
            .sorted { $0.roundNumber < $1.roundNumber }
            .last   // most recently published round
    }

    var myGroup: TeeSheetGroup? {
        guard let player = currentPlayer, let sheet = activeSheet else { return nil }
        return manager.myGroup(playerId: player.id, roundNumber: sheet.roundNumber)
    }

    var groupmates: [Player] {
        guard let group = myGroup, let me = currentPlayer else { return [] }
        return group.playerIds
            .compactMap { id in manager.players.first(where: { $0.id == id }) }
            .filter { $0.id != me.id }
    }

    var body: some View {
        if let sheet = activeSheet, let group = myGroup {
            VStack(spacing: 0) {
                Rectangle().fill(Color("DudeCupGreen")).frame(height: 3)

                ZStack {
                    Color(white: 0.06)
                    VStack(spacing: 16) {

                        // Label row
                        HStack {
                            Text("YOUR TEE TIME")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(5)
                                .foregroundStyle(Color("DudeCupGreen"))
                            Spacer()
                            Text("ROUND \(sheet.roundNumber)")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(3)
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Big tee time
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(group.teeTime, style: .time)
                                .font(.system(size: 52, weight: .black))
                                .fontWidth(.compressed)
                                .tracking(-2)
                                .foregroundStyle(.white)
                            Spacer()
                            // Countdown to tee
                            if group.teeTime > Date() {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("IN")
                                        .font(.system(size: 9, weight: .heavy))
                                        .tracking(3)
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text(group.teeTime, style: .relative)
                                        .font(.system(size: 16, weight: .black))
                                        .fontWidth(.compressed)
                                        .foregroundStyle(Color("DudeCupGreen"))
                                        .multilineTextAlignment(.trailing)
                                }
                            } else {
                                Text("TEE OFF!")
                                    .font(.system(size: 16, weight: .black))
                                    .fontWidth(.compressed)
                                    .foregroundStyle(Color("DudeCupGreen"))
                            }
                        }
                        .padding(.horizontal, 20)

                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                            .padding(.horizontal, 20)

                        // Playing with
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PLAYING WITH")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(4)
                                .foregroundStyle(.white.opacity(0.3))

                            HStack(spacing: 10) {
                                ForEach(groupmates) { player in
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(white: 0.15))
                                                .frame(width: 34, height: 34)
                                            Text(initials(player.name))
                                                .font(.system(size: 11, weight: .black))
                                                .fontWidth(.compressed)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(player.name.components(separatedBy: " ").first ?? player.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text("HCP \(player.handicap)")
                                                .font(.system(size: 9, weight: .heavy))
                                                .tracking(1)
                                                .foregroundStyle(.white.opacity(0.25))
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }

                Rectangle().fill(Color("DudeCupGreen")).frame(height: 3)
            }
        }
    }

    func initials(_ name: String) -> String {
        name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
    }
}


// MARK: - Schedule: Tee Times Section

struct ScheduleTeeTimesSection: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager

    var publishedSheets: [TeeSheet] {
        manager.teeSheets.filter { $0.isPublished }.sorted { $0.roundNumber < $1.roundNumber }
    }

    var body: some View {
        if !publishedSheets.isEmpty {
            VStack(alignment: .leading, spacing: 0) {

                // Section header
                HStack {
                    Text("TEE TIMES")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(5)
                        .foregroundStyle(Color("DudeCupGreen"))
                    Spacer()
                    Text("\(publishedSheets.count) ROUND\(publishedSheets.count == 1 ? "" : "S")")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

                VStack(spacing: 10) {
                    ForEach(publishedSheets) { sheet in
                        TeeSheetRoundCard(sheet: sheet)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct TeeSheetRoundCard: View {
    let sheet: TeeSheet
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager
    @State private var isExpanded = false

    var myGroup: TeeSheetGroup? {
        guard let player = authManager.currentPlayer else { return nil }
        return manager.myGroup(playerId: player.id, roundNumber: sheet.roundNumber)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Round header — always visible
            Button { withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() } } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("DudeCupGreen").opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("DudeCupGreen"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ROUND \(sheet.roundNumber)")
                            .font(.system(size: 14, weight: .heavy))
                            .fontWidth(.compressed)
                            .foregroundStyle(.white)

                        if let group = myGroup {
                            HStack(spacing: 4) {
                                Text("YOUR TIME:")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(2)
                                    .foregroundStyle(.white.opacity(0.3))
                                Text(group.teeTime, style: .time)
                                    .font(.system(size: 11, weight: .black))
                                    .fontWidth(.compressed)
                                    .foregroundStyle(Color("DudeCupGreen"))
                            }
                        }
                    }

                    Spacer()

                    Text("\(sheet.groups.count) GROUPS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.2))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            // Expanded group list
            if isExpanded {
                Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)

                VStack(spacing: 0) {
                    ForEach(Array(sheet.groups.enumerated()), id: \.element.id) { idx, group in
                        scheduleGroupRow(group: group, index: idx)
                        if idx < sheet.groups.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    myGroup != nil ? Color("DudeCupGreen").opacity(0.2) : Color.white.opacity(0.05),
                    lineWidth: 1
                )
        )
    }

    func scheduleGroupRow(group: TeeSheetGroup, index: Int) -> some View {
        let players = group.playerIds.compactMap { id in
            manager.players.first(where: { $0.id == id })
        }
        let isMyGroup = group.playerIds.contains(authManager.currentPlayer?.id ?? UUID())

        return HStack(spacing: 10) {
            // Time
            VStack(alignment: .trailing, spacing: 1) {
                Text(group.teeTime, style: .time)
                    .font(.system(size: 13, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(isMyGroup ? Color("DudeCupGreen") : .white.opacity(0.6))
            }
            .frame(width: 54)

            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 36)

            // Players
            HStack(spacing: 6) {
                ForEach(players) { player in
                    Text(player.name.components(separatedBy: " ").first ?? player.name)
                        .font(.system(size: 12, weight: isMyGroup ? .bold : .semibold))
                        .foregroundStyle(
                            player.id == authManager.currentPlayer?.id
                            ? Color("DudeCupGreen")
                            : .white.opacity(isMyGroup ? 0.8 : 0.45)
                        )
                }
            }

            Spacer()

            if isMyGroup {
                Text("YOU")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color("DudeCupGreen"))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMyGroup ? Color("DudeCupGreen").opacity(0.04) : Color.clear)
    }
}
