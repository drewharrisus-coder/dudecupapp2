//
//  PlayerProfileView.swift
//  The Rug
//
//  Created for The Dude Cup 2026
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

// MARK: - Player Profile Main View

struct PlayerProfileView: View {
    let player: Player
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab = 0
    @State private var earnedBadges: [Badge] = []

    // Photo upload
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var uploadError: String?
    @State private var localPhotoURL: String?   // overrides player.photoURL after upload

    // Commish edit
    @State private var showingCommishEdit = false

    var isOwnProfile: Bool { authManager.currentPlayer?.id == player.id }
    var isCommish: Bool { authManager.currentPlayer?.team == "Commish" || authManager.currentPlayer?.name == "Andrew H." }
    var playerScore: Score? { manager.scores.first { $0.playerId == player.id } }
    var resolvedPhotoURL: String? { localPhotoURL ?? player.photoURL }

    var totalStableford: Int {
        guard let score = playerScore else { return 0 }
        return manager.stablefordTotal(score: score, player: player)
    }

    var currentPosition: Int {
        let ranked = manager.players.sorted { p1, p2 in
            guard let s1 = manager.scores.first(where: { $0.playerId == p1.id }),
                  let s2 = manager.scores.first(where: { $0.playerId == p2.id }) else { return false }
            return manager.stablefordTotal(score: s1, player: p1) > manager.stablefordTotal(score: s2, player: p2)
        }
        return (ranked.firstIndex(where: { $0.id == player.id }) ?? 0) + 1
    }

    var positionText: String {
        switch currentPosition {
        case 1: return "1ST"; case 2: return "2ND"; case 3: return "3RD"
        default: return "\(currentPosition)TH"
        }
    }

    var initials: String {
        player.name.split(separator: Character(" ")).compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    var tabs: [(label: String, tag: Int)] {
        isOwnProfile
            ? [("OVERVIEW", 0), ("MY BETS", 1), ("STATS", 2), ("HISTORY", 3)]
            : [("OVERVIEW", 0), ("STATS", 1), ("HISTORY", 2)]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                profileHeader
                tabBar
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                ScrollView {
                    VStack(spacing: 0) {
                        tabContent.padding(.horizontal, 16).padding(.top, 20)
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if isCommish && !isOwnProfile {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingCommishEdit = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(Color("DudeCupGreen"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingCommishEdit) {
            CommishEditPlayerSheet(player: player)
                .environment(manager)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await uploadPhoto(item: item) }
        }
        .onAppear { earnedBadges = calculateBadges() }
    }

    // ── PROFILE HEADER ────────────────────────────────────────────────────────
    var profileHeader: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color("DudeCupGreen").opacity(0.12), Color.clear],
                           center: .top, startRadius: 0, endRadius: 220)
            VStack(spacing: 0) {
                HStack(spacing: 16) {

                    // ── Avatar / Photo ──
                    ZStack(alignment: .bottomTrailing) {
                        if let urlStr = resolvedPhotoURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                        .frame(width: 72, height: 72).clipShape(Circle())
                                case .failure(_):
                                    initialsCircle
                                default:
                                    ZStack {
                                        Circle().fill(Color(white: 0.15)).frame(width: 72, height: 72)
                                        ProgressView().tint(.white.opacity(0.4))
                                    }
                                }
                            }
                        } else {
                            initialsCircle
                        }

                        // Upload button — own profile only
                        if isOwnProfile {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                ZStack {
                                    Circle().fill(Color.black).frame(width: 24, height: 24)
                                    if isUploadingPhoto {
                                        ProgressView().scaleEffect(0.6).tint(.white)
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .offset(x: 4, y: 4)
                            .disabled(isUploadingPhoto)
                        }
                    }

                    // ── Name / Meta ──
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name.uppercased())
                            .font(.system(size: 22, weight: .black)).fontWidth(.compressed).tracking(0.5)
                            .foregroundStyle(.white)

                        if let nick = player.nickname, !nick.isEmpty {
                            Text("\u{201C}\(nick)\u{201D}")
                                .font(.system(size: 12, weight: .semibold)).italic()
                                .foregroundStyle(Color("DudeCupGreen").opacity(0.8))
                        }

                        HStack(spacing: 8) {
                            if !player.team.isEmpty {
                                Text(player.team.uppercased())
                                    .font(.system(size: 9, weight: .heavy)).tracking(2)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            if let debut = player.debutYear {
                                Text("· SINCE \(String(format: "%d", debut))")
                                    .font(.system(size: 9, weight: .heavy)).tracking(1)
                                    .foregroundStyle(Color("DudeCupGreen").opacity(0.5))
                            }
                        }

                        if !earnedBadges.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(earnedBadges.prefix(3)) { b in Text(b.emoji).font(.system(size: 13)) }
                            }
                        }
                    }
                    Spacer()

                    // ── Confirmed badge ──
                    if player.isConfirmed {
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color("DudeCupGreen"))
                            Text("CONFIRMED")
                                .font(.system(size: 7, weight: .heavy)).tracking(1)
                                .foregroundStyle(Color("DudeCupGreen").opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)

                // ── Quick contact strip (non-own profiles) ──
                if !isOwnProfile {
                    contactStrip
                }

                // ── Stat pills ──
                HStack(spacing: 0) {
                    statPill("\(totalStableford)", "POINTS")
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 36)
                    statPill(positionText, "POSITION")
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 36)
                    statPill("\(player.handicap)", "HANDICAP")
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 36)
                    statPill("\(playerScore?.rounds.filter { $0.isComplete }.count ?? 0)", "ROUNDS")
                }
                .background(Color(white: 0.06))
            }
        }
    }

    // Quick tap-to-call / Venmo strip shown on other players' profiles
    var contactStrip: some View {
        HStack(spacing: 0) {
            if !player.phone.isEmpty {
                contactButton(icon: "phone.fill", label: "CALL") {
                    let clean = player.phone.filter { $0.isNumber }
                    if let url = URL(string: "tel:\(clean)") { UIApplication.shared.open(url) }
                }
            }
            if !player.phone.isEmpty {
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                contactButton(icon: "message.fill", label: "TEXT") {
                    let clean = player.phone.filter { $0.isNumber }
                    if let url = URL(string: "sms:\(clean)") { UIApplication.shared.open(url) }
                }
            }
            if let venmo = player.venmoHandle, !venmo.isEmpty {
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                contactButton(icon: "dollarsign.circle.fill", label: "VENMO") {
                    let handle = venmo.replacingOccurrences(of: "@", with: "")
                    if let url = URL(string: "venmo://paycharge?txn=pay&recipients=\(handle)") {
                        UIApplication.shared.open(url)
                    } else if let url = URL(string: "https://venmo.com/\(handle)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            if !player.email.isEmpty {
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                contactButton(icon: "envelope.fill", label: "EMAIL") {
                    if let url = URL(string: "mailto:\(player.email)") { UIApplication.shared.open(url) }
                }
            }
        }
        .background(Color(white: 0.05))
    }

    func contactButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("DudeCupGreen"))
                Text(label)
                    .font(.system(size: 8, weight: .heavy)).tracking(2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(isOwnProfile ? Color("DudeCupGreen") : Color(white: 0.15))
                .frame(width: 72, height: 72)
            Text(initials)
                .font(.system(size: 26, weight: .black)).fontWidth(.compressed)
                .foregroundStyle(isOwnProfile ? .black : .white)
        }
    }

    // ── Photo Upload ──────────────────────────────────────────────────────────
    func uploadPhoto(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await MainActor.run { isUploadingPhoto = true }
        do {
            let storage = Storage.storage()
            let clean = player.phone.filter { $0.isNumber }
            let path = "playerPhotos/\(clean)_\(Date().timeIntervalSince1970).jpg"
            let ref = storage.reference().child(path)
            let _ = try await ref.putData(data)
            let url = try await ref.downloadURL()
            // Save back to Firestore
            let db = Firestore.firestore()
            try await db.collection("players").document(player.id.uuidString)
                .updateData(["photoURL": url.absoluteString])
            await MainActor.run {
                localPhotoURL = url.absoluteString
                isUploadingPhoto = false
            }
        } catch {
            await MainActor.run {
                uploadError = error.localizedDescription
                isUploadingPhoto = false
            }
        }
    }

    func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .black)).fontWidth(.compressed)
                .foregroundStyle(Color("DudeCupGreen")).monospacedDigit()
            Text(label).font(.system(size: 8, weight: .heavy)).tracking(2)
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }

    // ── TAB BAR ───────────────────────────────────────────────────────────────
    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab.tag }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.label)
                            .font(.system(size: 10, weight: .heavy)).tracking(2)
                            .foregroundStyle(selectedTab == tab.tag ? Color("DudeCupGreen") : .white.opacity(0.3))
                        Rectangle()
                            .fill(selectedTab == tab.tag ? Color("DudeCupGreen") : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity).padding(.top, 14)
            }
        }
        .background(Color.black)
    }

    // ── TAB CONTENT ───────────────────────────────────────────────────────────
    @ViewBuilder
    var tabContent: some View {
        if isOwnProfile {
            switch selectedTab {
            case 0: OverviewTab(player: player, badges: earnedBadges)
            case 1: MyBetsTab(player: player)
            case 2: StatsTab(player: player)
            default: HistoryTab(player: player)
            }
        } else {
            switch selectedTab {
            case 0: OverviewTab(player: player, badges: earnedBadges)
            case 1: StatsTab(player: player)
            default: HistoryTab(player: player)
            }
        }
    }

    func calculateBadges() -> [Badge] {
        var badges: [Badge] = []
        guard let score = playerScore else { return badges }
        for round in score.rounds {
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { continue }
            for (i, hole) in round.holes.enumerated() where i < course.holes.count {
                if hole.strokes > 0 && hole.strokes <= course.holes[i].par - 2 {
                    badges.append(Badge(emoji: "🦅", name: "Eagle Eye", description: "Scored an eagle", earnedAt: Date())); break
                }
            }
            if badges.contains(where: { $0.emoji == "🦅" }) { break }
        }
        for round in score.rounds where round.holes.contains(where: { $0.strokes == 8 }) {
            badges.append(Badge(emoji: "⛄", name: "Snowman", description: "Scored an 8", earnedAt: Date())); break
        }
        if currentPosition == 1 { badges.append(Badge(emoji: "🏆", name: "Champion", description: "Tournament leader", earnedAt: Date())) }
        if manager.betEntries.filter({ $0.playerId == player.id && $0.status == .paid }).count == 4 {
            badges.append(Badge(emoji: "🎰", name: "All In", description: "Entered all bets", earnedAt: Date()))
        }
        return badges.sorted { $0.earnedAt > $1.earnedAt }
    }
}

// MARK: - Shared helpers

private func sectionLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .heavy)).tracking(4)
        .foregroundStyle(Color("DudeCupGreen")).padding(.bottom, 10)
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let player: Player
    let badges: [Badge]
    @Environment(TournamentManager.self) private var manager
    var playerScore: Score? { manager.scores.first { $0.playerId == player.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // ── About Me ──
            if let about = player.aboutMe, !about.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("ABOUT")
                    Text(about)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineSpacing(4)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // ── Player info card ──
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("PLAYER INFO")
                VStack(spacing: 0) {
                    if !player.hometown.isEmpty {
                        infoRow(icon: "mappin.circle.fill", label: "Hometown", value: player.hometown, color: .orange)
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 50)
                    }
                    if let debut = player.debutYear {
                        infoRow(icon: "flag.fill", label: "Dude Cup Debut", value: String(format: "%d", debut), color: Color("DudeCupGreen"))
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 50)
                    }
                    infoRow(icon: "flag.fill", label: "Handicap", value: "\(player.handicap)", color: .white.opacity(0.6))
                    if let ghin = player.ghinNumber, !ghin.isEmpty {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 50)
                        infoRow(icon: "number.circle.fill", label: "GHIN", value: ghin, color: .white.opacity(0.4))
                    }
                    if !player.team.isEmpty {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 50)
                        infoRow(icon: "person.2.fill", label: "Team", value: player.team, color: Color("DudeCupGreen").opacity(0.7))
                    }
                }
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // ── Achievements ──
            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("ACHIEVEMENTS")
                    VStack(spacing: 0) {
                        ForEach(Array(badges.enumerated()), id: \.element.id) { i, badge in
                            HStack(spacing: 14) {
                                Text(badge.emoji).font(.system(size: 28)).frame(width: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(badge.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                    Text(badge.description).font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < badges.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 70)
                            }
                        }
                    }
                    .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // ── Current Round ──
            if let score = playerScore, let round = score.rounds.last {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("CURRENT ROUND")
                    VStack(spacing: 0) {
                        HStack {
                            Text("ROUND \(round.roundNumber)")
                                .font(.system(size: 14, weight: .heavy)).fontWidth(.compressed).foregroundStyle(.white)
                            Spacer()
                            if round.isAttested {
                                Label("LOCKED", systemImage: "lock.fill")
                                    .font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(Color("DudeCupGreen"))
                            } else {
                                Text("\(round.holesPlayed)/18")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        if let course = manager.courses.first(where: { $0.id == round.courseId }) {
                            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                            HStack {
                                Text(course.name.uppercased())
                                    .font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.3))
                                Spacer()
                                if round.totalGross > 0 {
                                    Text("\(round.totalGross)")
                                        .font(.system(size: 20, weight: .black)).fontWidth(.compressed).foregroundStyle(.white.opacity(0.7))
                                    Text("STROKES")
                                        .font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.2)).padding(.leading, 4)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                    }
                    .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if playerScore == nil {
                VStack(spacing: 10) {
                    Text("⛳️").font(.system(size: 40))
                    Text("NO SCORES YET").font(.system(size: 14, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 48)
            }
        }
    }

    func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}

// MARK: - My Bets Tab

struct MyBetsTab: View {
    let player: Player
    @Environment(TournamentManager.self) private var manager

    var playerEntries: [PlayerBetEntry] { manager.betEntries.filter { $0.playerId == player.id } }

    // Per-bet status
    func entryStatus(for bet: Bet) -> BetStatus {
        if bet.type == .skins {
            let rounds = (1...4).filter { manager.isEnteredSkins(playerId: player.id, round: $0) }.count
            return rounds > 0 ? .paid : .notEntered
        }
        return playerEntries.first(where: { $0.betId == bet.id })?.status ?? .notEntered
    }

    func skinsRoundsEntered() -> Int {
        (1...4).filter { manager.isEnteredSkins(playerId: player.id, round: $0) }.count
    }

    var totalIn: Double {
        manager.bets.reduce(0.0) { sum, bet in
            if bet.type == .skins {
                return sum + Double(skinsRoundsEntered()) * bet.amount
            }
            let status = entryStatus(for: bet)
            return sum + (status == .paid || status == .paymentPending ? bet.amount : 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // ── Status summary ──
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("2026 BETS")
                VStack(spacing: 0) {
                    ForEach(Array(manager.bets.enumerated()), id: \.element.id) { i, bet in
                        betSummaryRow(bet: bet)
                        if i < manager.bets.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16)
                        }
                    }
                    // Total row
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    HStack {
                        Text("TOTAL IN").font(.system(size: 10, weight: .heavy)).tracking(3)
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                        Text("$\(Int(totalIn))")
                            .font(.system(size: 28, weight: .black)).fontWidth(.compressed)
                            .foregroundStyle(totalIn > 0 ? Color("DudeCupGreen") : .white.opacity(0.2))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // ── Go to Betting & Props ──
            NavigationLink(destination: BettingView()) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: "dice.fill").font(.system(size: 18)).foregroundStyle(.purple)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BETTING & PROPS")
                            .font(.system(size: 14, weight: .heavy)).fontWidth(.compressed)
                            .foregroundStyle(.white)
                        Text("Enter bets, view pots, manage skins")
                            .font(.system(size: 10, weight: .heavy)).tracking(1)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(16)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // ── Lifetime stats ──
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("LIFETIME STATS")
                VStack(spacing: 0) {
                    lRow("Total Wagered", "$0")
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16)
                    lRow("Total Won", "$0")
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    HStack {
                        Text("NET").font(.system(size: 10, weight: .heavy)).tracking(3)
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                        Text("$0").font(.system(size: 22, weight: .black)).fontWidth(.compressed)
                            .foregroundStyle(.white.opacity(0.4))
                    }.padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    func betSummaryRow(bet: Bet) -> some View {
        let status = entryStatus(for: bet)
        let isIn = status == .paid || status == .paymentPending

        return HStack(spacing: 14) {
            Text(betEmoji(bet.type)).font(.system(size: 22)).frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(bet.type.rawValue.uppercased())
                    .font(.system(size: 12, weight: .heavy)).tracking(0.5).foregroundStyle(.white)
                if bet.type == .skins {
                    let r = skinsRoundsEntered()
                    Text(r > 0 ? "\(r) OF 4 ROUNDS · $\(r * Int(bet.amount))" : "NOT ENTERED")
                        .font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundStyle(r == 4 ? Color("DudeCupGreen") : r > 0 ? .orange : .white.opacity(0.25))
                } else {
                    Text(isIn ? status.rawValue.uppercased() : "NOT ENTERED")
                        .font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundStyle(status == .paid ? Color("DudeCupGreen") : isIn ? .orange : .white.opacity(0.25))
                }
            }
            Spacer()
            if isIn || (bet.type == .skins && skinsRoundsEntered() > 0) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color("DudeCupGreen"))
            } else {
                Text("$\(Int(bet.amount))")
                    .font(.system(size: 14, weight: .bold)).fontWidth(.compressed)
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    func lRow(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(v).font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.5))
        }.padding(.horizontal, 16).padding(.vertical, 13)
    }

    func betEmoji(_ type: BetType) -> String {
        switch type {
        case .tournamentPurse: return "🏆"
        case .closestToPin:    return "🎯"
        case .random9:         return "🎲"
        case .deuces:          return "2️⃣"
        case .skins:           return "💰"
        }
    }
}

// MARK: - Stats Tab

struct StatsTab: View {
    let player: Player
    @Environment(TournamentManager.self) private var manager
    var playerScore: Score? { manager.scores.first { $0.playerId == player.id } }

    // ── Scoring stats ──
    var completedRounds: [RoundScore] {
        playerScore?.rounds.filter { $0.isComplete } ?? []
    }

    var avgStableford: Double {
        guard !completedRounds.isEmpty else { return 0 }
        let total = completedRounds.reduce(0) { sum, round in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return sum }
            return sum + round.holes.enumerated().reduce(0) { rs, pair in
                rs + course.stablefordPoints(hole: pair.offset + 1, strokes: pair.element.strokes, handicapIndex: player.handicap)
            }
        }
        return Double(total) / Double(completedRounds.count)
    }

    var bestRoundPoints: Int {
        completedRounds.map { round -> Int in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return 0 }
            return round.holes.enumerated().reduce(0) { rs, pair in
                rs + course.stablefordPoints(hole: pair.offset + 1, strokes: pair.element.strokes, handicapIndex: player.handicap)
            }
        }.max() ?? 0
    }

    var totalBirdiesOrBetter: Int {
        guard let score = playerScore else { return 0 }
        return score.rounds.flatMap { round -> [Int] in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return [] }
            return round.holes.enumerated().compactMap { i, hole in
                guard i < course.holes.count, hole.strokes > 0 else { return nil }
                return hole.strokes <= course.holes[i].par - 1 ? 1 : nil
            }
        }.count
    }

    var totalEagles: Int {
        guard let score = playerScore else { return 0 }
        return score.rounds.flatMap { round -> [Int] in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return [] }
            return round.holes.enumerated().compactMap { i, hole in
                guard i < course.holes.count, hole.strokes > 0 else { return nil }
                return hole.strokes <= course.holes[i].par - 2 ? 1 : nil
            }
        }.count
    }

    var totalPars: Int {
        guard let score = playerScore else { return 0 }
        return score.rounds.flatMap { round -> [Int] in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return [] }
            return round.holes.enumerated().compactMap { i, hole in
                guard i < course.holes.count, hole.strokes > 0 else { return nil }
                return hole.strokes == course.holes[i].par ? 1 : nil
            }
        }.count
    }

    var totalBogeys: Int {
        guard let score = playerScore else { return 0 }
        return score.rounds.flatMap { round -> [Int] in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return [] }
            return round.holes.enumerated().compactMap { i, hole in
                guard i < course.holes.count, hole.strokes > 0 else { return nil }
                return hole.strokes == course.holes[i].par + 1 ? 1 : nil
            }
        }.count
    }

    var totalDoublePlus: Int {
        guard let score = playerScore else { return 0 }
        return score.rounds.flatMap { round -> [Int] in
            guard let course = manager.courses.first(where: { $0.id == round.courseId }) else { return [] }
            return round.holes.enumerated().compactMap { i, hole in
                guard i < course.holes.count, hole.strokes > 0 else { return nil }
                return hole.strokes >= course.holes[i].par + 2 ? 1 : nil
            }
        }.count
    }

    var holesPlayed: Int {
        playerScore?.rounds.reduce(0) { $0 + $1.holesPlayed } ?? 0
    }

    // ── Challenge stats ──
    var playerChallenges: [Challenge] {
        manager.challenges.filter {
            ($0.challengerId == player.id || $0.challengedId == player.id) &&
            $0.status == .resolved
        }
    }
    var challengesWon: Int {
        playerChallenges.filter { $0.winnerId == player.id }.count
    }
    var challengesLost: Int { playerChallenges.count - challengesWon }

    var dcpiData: DCPIData? { manager.calculateDCPI(for: player.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // ── DCPI ──
            if let dcpi = dcpiData {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("DUDE CUP PERFORMANCE INDEX")
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DCPI").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                                Text(String(format: "%.1f", dcpi.currentDCPI))
                                    .font(.system(size: 44, weight: .black)).fontWidth(.compressed)
                                    .foregroundStyle(Color("DudeCupGreen"))
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("OFFICIAL HCP").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                                Text("\(player.handicap)")
                                    .font(.system(size: 44, weight: .black)).fontWidth(.compressed)
                                    .foregroundStyle(.white.opacity(0.25))
                            }.frame(maxWidth: .infinity, alignment: .trailing).padding(16)
                        }
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: trendIcon(dcpi.trend)).font(.system(size: 11, weight: .bold))
                                Text(dcpi.trend.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(2)
                            }.foregroundStyle(trendColor(dcpi.trend))
                            Spacer()
                            Text("BASED ON \(dcpi.totalRounds) ROUNDS")
                                .font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.2))
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // ── Scoring ──
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("SCORING")
                VStack(spacing: 0) {
                    statRow("Rounds Played",       "\(completedRounds.count) of \(playerScore?.rounds.count ?? 0)")
                    divider()
                    statRow("Holes Played",         "\(holesPlayed)")
                    divider()
                    statRow("Avg Points / Round",   completedRounds.isEmpty ? "—" : String(format: "%.1f", avgStableford))
                    divider()
                    statRow("Best Round",           bestRoundPoints > 0 ? "\(bestRoundPoints) pts" : "—")
                }
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // ── Hole Results ──
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("HOLE RESULTS")
                VStack(spacing: 0) {
                    statRow("🦅  Eagles",           "\(totalEagles)",   color: Color("DudeCupGreen"))
                    divider()
                    statRow("🐦  Birdies",          "\(totalBirdiesOrBetter - totalEagles)", color: Color("DudeCupGreen").opacity(0.7))
                    divider()
                    statRow("⛳  Pars",              "\(totalPars)",     color: .white.opacity(0.6))
                    divider()
                    statRow("📈  Bogeys",            "\(totalBogeys)",   color: .orange.opacity(0.8))
                    divider()
                    statRow("💀  Double+",           "\(totalDoublePlus)", color: .red.opacity(0.7))
                }
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // ── Challenges ──
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("CHALLENGES")
                VStack(spacing: 0) {
                    statRow("Total Challenges",     "\(playerChallenges.count)")
                    divider()
                    statRow("Won",                  "\(challengesWon)",  color: Color("DudeCupGreen"))
                    divider()
                    statRow("Lost",                 "\(challengesLost)", color: challengesLost > 0 ? .red.opacity(0.7) : .white.opacity(0.5))
                    divider()
                    statRow("Win Rate", playerChallenges.isEmpty ? "—" :
                        String(format: "%.0f%%", Double(challengesWon) / Double(playerChallenges.count) * 100))
                }
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Empty state
            if completedRounds.isEmpty {
                VStack(spacing: 8) {
                    Text("📊").font(.system(size: 36))
                    Text("Stats build as rounds are completed.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            }
        }
    }

    func statRow(_ label: String, _ value: String, color: Color = .white.opacity(0.75)) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
        }.padding(.horizontal, 16).padding(.vertical, 13)
    }

    func divider() -> some View {
        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16)
    }

    func trendIcon(_ t: String) -> String { t == "Improving" ? "arrow.down.right" : t == "Declining" ? "arrow.up.right" : "arrow.right" }
    func trendColor(_ t: String) -> Color { t == "Improving" ? Color("DudeCupGreen") : t == "Declining" ? .red : .white.opacity(0.4) }
}

// MARK: - History Tab

struct HistoryTab: View {
    let player: Player
    var body: some View {
        VStack(spacing: 12) {
            Text("📚").font(.system(size: 48))
            Text("HISTORY COMING IN V2").font(.system(size: 14, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.2))
            Text("Past tournament data will live here after the season ends.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.15)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

// MARK: - Commish Edit Player Sheet

struct CommishEditPlayerSheet: View {
    let player: Player
    @Environment(TournamentManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var handicap: String = ""
    @State private var team: String = ""
    @State private var isConfirmed: Bool = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EDIT PLAYER")
                                .font(.system(size: 10, weight: .heavy)).tracking(4)
                                .foregroundStyle(Color("DudeCupGreen"))
                            Text(player.name)
                                .font(.system(size: 22, weight: .black)).fontWidth(.compressed)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .padding(20)

                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

                    ScrollView {
                        VStack(spacing: 24) {

                            // Handicap
                            VStack(alignment: .leading, spacing: 10) {
                                Text("HANDICAP")
                                    .font(.system(size: 9, weight: .heavy)).tracking(4)
                                    .foregroundStyle(Color("DudeCupGreen"))
                                HStack {
                                    Button {
                                        let v = (Int(handicap) ?? 0) - 1
                                        handicap = "\(max(0, v))"
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28)).foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Text(handicap)
                                        .font(.system(size: 52, weight: .black)).fontWidth(.compressed)
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 80, alignment: .center)
                                    Spacer()
                                    Button {
                                        let v = (Int(handicap) ?? 0) + 1
                                        handicap = "\(min(54, v))"
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28)).foregroundStyle(Color("DudeCupGreen"))
                                    }
                                }
                                .padding(20)
                                .background(Color(white: 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Team
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TEAM ASSIGNMENT")
                                    .font(.system(size: 9, weight: .heavy)).tracking(4)
                                    .foregroundStyle(Color("DudeCupGreen"))
                                VStack(spacing: 0) {
                                    ForEach(["Team Abide", "Team Aggression", ""], id: \.self) { t in
                                        Button {
                                            team = t
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } label: {
                                            HStack {
                                                Text(t.isEmpty ? "Unassigned" : t)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(t.isEmpty ? .white.opacity(0.25) : .white)
                                                Spacer()
                                                if team == t {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(Color("DudeCupGreen"))
                                                }
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 14)
                                        }
                                        .buttonStyle(.plain)
                                        if t != "" {
                                            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                                        }
                                    }
                                }
                                .background(Color(white: 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Confirmed toggle
                            VStack(alignment: .leading, spacing: 10) {
                                Text("STATUS")
                                    .font(.system(size: 9, weight: .heavy)).tracking(4)
                                    .foregroundStyle(Color("DudeCupGreen"))
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Confirmed Participant")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("Player has paid deposit and is locked in")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    Spacer()
                                    Toggle("", isOn: $isConfirmed)
                                        .tint(Color("DudeCupGreen"))
                                        .labelsHidden()
                                }
                                .padding(16)
                                .background(Color(white: 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Save
                            Button {
                                Task { await saveChanges() }
                            } label: {
                                HStack(spacing: 8) {
                                    if isSaving { ProgressView().tint(.black).scaleEffect(0.8) }
                                    Text(isSaving ? "SAVING…" : "SAVE CHANGES")
                                        .font(.system(size: 13, weight: .heavy)).tracking(2)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("DudeCupGreen"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isSaving)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            handicap = "\(player.handicap)"
            team = player.team
            isConfirmed = player.isConfirmed
        }
    }

    func saveChanges() async {
        await MainActor.run { isSaving = true }
        let db = Firestore.firestore()
        do {
            try await db.collection("players").document(player.id.uuidString).updateData([
                "handicap": Int(handicap) ?? player.handicap,
                "team": team,
                "isConfirmed": isConfirmed
            ])
        } catch {
            print("❌ Save failed: \(error)")
        }
        await MainActor.run { isSaving = false }
        dismiss()
    }
}
