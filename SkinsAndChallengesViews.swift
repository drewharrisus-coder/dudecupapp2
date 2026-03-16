//
//  SkinsAndChallengesViews.swift
//  The Rug
//

import SwiftUI

func sLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .heavy)).tracking(4)
        .foregroundStyle(Color("DudeCupGreen"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 10)
}

struct SkinsView: View {
    let bet: Bet
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore
    @Environment(AuthManager.self) private var authManager

    var me: Player? { authManager.currentPlayer }
    let allRounds = [1, 2, 3, 4]

    var enteredRounds: [Int] {
        guard let me else { return [] }
        return allRounds.filter { bettingStore.isEnteredSkins(playerId: me.id, round: $0) }
    }

    var totalPot: Double { allRounds.reduce(0) { $0 + bettingStore.skinsPot(for: $1) } }
    var myTotalCost: Double { Double(enteredRounds.count) * bet.amount }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    skinsHero
                    myEntrySection
                    roundCards
                    howItWorks
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Skins").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    var skinsHero: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color("DudeCupGreen").opacity(0.15), Color.clear], center: .top, startRadius: 0, endRadius: 200)
            VStack(spacing: 4) {
                Text("💰 SKINS").font(.system(size: 9, weight: .heavy)).tracking(5)
                    .foregroundStyle(Color("DudeCupGreen")).padding(.top, 28)
                Text("$\(Int(totalPot))")
                    .font(.system(size: 72, weight: .black)).fontWidth(.compressed).tracking(-2).foregroundStyle(.white)
                Text("TOTAL LIVE POT ACROSS ALL ROUNDS").font(.system(size: 9, weight: .heavy)).tracking(3)
                    .foregroundStyle(.white.opacity(0.2)).padding(.bottom, 28)
            }
        }
    }

    var myEntrySection: some View {
        VStack(spacing: 0) {
            sLabel("YOUR ENTRY")
            VStack(spacing: 10) {
                HStack {
                    if enteredRounds.isEmpty {
                        Text("Not entered in any round")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.3))
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("IN FOR \(enteredRounds.count) ROUND\(enteredRounds.count == 1 ? "" : "S")")
                                .font(.system(size: 13, weight: .heavy)).foregroundStyle(Color("DudeCupGreen"))
                            Text("Rounds \(enteredRounds.map(String.init).joined(separator: ", "))")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                    if myTotalCost > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(Int(myTotalCost))").font(.system(size: 22, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
                            Text("YOUR TOTAL").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
                .padding(16).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))

                if enteredRounds.count < 4, let me {
                    Button {
                        for r in allRounds where !bettingStore.isEnteredSkins(playerId: me.id, round: r) {
                            bettingStore.enterSkins(playerId: me.id, round: r)
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 14, weight: .bold))
                            Text("ENTER ALL 4 ROUNDS — $\(Int(bet.amount * 4))")
                                .font(.system(size: 12, weight: .heavy)).tracking(1)
                        }
                        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color("DudeCupGreen")).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    var roundCards: some View {
        VStack(spacing: 0) {
            sLabel("ROUNDS")
            VStack(spacing: 10) {
                ForEach(allRounds, id: \.self) { round in
                    SkinsRoundCard(round: round, bet: bet)
                }
            }.padding(.horizontal, 16)
        }
    }

    var howItWorks: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("HOW IT WORKS")
            VStack(alignment: .leading, spacing: 14) {
                ruleRow("💵", "$\(Int(bet.amount)) per round — buy in to any or all")
                ruleRow("⛳️", "Each round has its own independent pot")
                ruleRow("🐦", "Score birdie or better in a round you're entered to win")
                ruleRow("🤝", "Multiple birdie scorers split that round's pot equally")
                ruleRow("🔒", "Round must be attested for payouts to calculate")
            }
            .padding(16).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
        }
    }

    func ruleRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 18))
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
        }
    }
}

struct SkinsRoundCard: View {
    let round: Int
    let bet: Bet
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore
    @Environment(AuthManager.self) private var authManager

    var me: Player? { authManager.currentPlayer }
    var pot: Double       { bettingStore.skinsPot(for: round) }
    var winners: [Player] { bettingStore.skinsWinners(for: round) }
    var payout: Double    { bettingStore.skinsPayoutPerWinner(for: round) }
    var entrants: [Player] { bettingStore.skinsEntrants(for: round) }
    var isResolved: Bool  { !winners.isEmpty }
    var amEntered: Bool   { guard let me else { return false }; return bettingStore.isEnteredSkins(playerId: me.id, round: round) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ROUND \(round)").font(.system(size: 12, weight: .heavy)).tracking(3).foregroundStyle(Color("DudeCupGreen"))
                Spacer()
                Text("$\(Int(pot)) POT").font(.system(size: 16, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).background(Color(white: 0.1))

            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)

            if isResolved {
                ForEach(Array(winners.enumerated()), id: \.element.id) { idx, winner in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color("DudeCupGreen").opacity(0.15)).frame(width: 34, height: 34)
                            Text(initials(winner.name)).font(.system(size: 11, weight: .black)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(winner.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            Text("BIRDIE OR BETTER").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        Text("+$\(Int(payout))").font(.system(size: 18, weight: .black)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    if idx < winners.count - 1 { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 60) }
                }
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: amEntered ? "checkmark.circle.fill" : "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(amEntered ? Color("DudeCupGreen") : .white.opacity(0.2))
                        Text(amEntered ? "You're in — waiting for round" : entrants.isEmpty ? "No entries yet" : "Waiting for round to complete…")
                            .font(.system(size: 12))
                            .foregroundStyle(amEntered ? .white.opacity(0.5) : .white.opacity(0.25))
                        Spacer()
                        Text("\(entrants.count) IN").font(.system(size: 9, weight: .heavy)).tracking(2)
                            .foregroundStyle(amEntered ? Color("DudeCupGreen").opacity(0.6) : .white.opacity(0.2))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14)

                    if !amEntered, let me {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                        Button {
                            bettingStore.enterSkins(playerId: me.id, round: round)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 13, weight: .bold))
                                Text("ENTER ROUND \(round) — $\(Int(bet.amount))")
                                    .font(.system(size: 12, weight: .heavy)).tracking(1)
                            }
                            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Color("DudeCupGreen"))
                        }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0))
                    }
                }
            }
        }
        .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isResolved ? Color("DudeCupGreen").opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1))
    }

    func initials(_ name: String) -> String {
        name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
    }
}

// MARK: - Challenges Hub

struct ChallengesView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore
    @Environment(AuthManager.self) private var authManager
    @State private var showIssueSheet = false

    var me: Player? { authManager.currentPlayer }

    var needsMyResponse: [Challenge] {
        guard let me else { return [] }
        return bettingStore.challenges.filter {
            ($0.challengedId == me.id.uuidString && $0.status == .pending) ||
            ($0.challengerId == me.id.uuidString && $0.status == .strokesCountered)
        }.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }

    var activeChallenges: [Challenge] {
        bettingStore.challenges
            .filter { $0.status == .active || ($0.status == .pending && $0.challengedId != me?.id.uuidString) }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }

    var resolvedChallenges: [Challenge] {
        bettingStore.challenges
            .filter { $0.status == .resolved || $0.status == .tied || $0.status == .declined }
            .sorted { ($0.resolvedAt ?? $0.createdAt ?? Date()) > ($1.resolvedAt ?? $1.createdAt ?? Date()) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    challengesHeader
                    if !needsMyResponse.isEmpty { responseSection }
                    if !activeChallenges.isEmpty { challengeSection(label: "ACTIVE", challenges: activeChallenges) }
                    if !resolvedChallenges.isEmpty { challengeSection(label: "SETTLED", challenges: resolvedChallenges) }
                    if bettingStore.challenges.isEmpty { emptyState }
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Challenges").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showIssueSheet) {
            IssueChallengeSheet()
                .environment(manager).environment(bettingStore).environment(authManager)
        }
    }

    var challengesHeader: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color.orange.opacity(0.15), Color.clear], center: .top, startRadius: 0, endRadius: 200)
            VStack(spacing: 4) {
                Text("🤜🤛").font(.system(size: 40)).padding(.top, 24)
                Text("CHALLENGES").font(.system(size: 42, weight: .black)).fontWidth(.compressed).tracking(-1).foregroundStyle(.white)
                Text("\(activeChallenges.count) ACTIVE · \(resolvedChallenges.count) SETTLED")
                    .font(.system(size: 9, weight: .heavy)).tracking(4).foregroundStyle(.white.opacity(0.2)).padding(.bottom, 20)
                Button { showIssueSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 14, weight: .bold))
                        Text("ISSUE A CHALLENGE").font(.system(size: 12, weight: .heavy)).tracking(1)
                    }
                    .foregroundStyle(.black).padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.orange).clipShape(Capsule())
                }
                .padding(.bottom, 24)
            }
        }
    }

    var responseSection: some View {
        VStack(spacing: 0) {
            sLabel("NEEDS YOUR RESPONSE")
            VStack(spacing: 8) {
                ForEach(needsMyResponse) { challenge in
                    if challenge.status == .pending {
                        PendingChallengeCard(challenge: challenge)
                    } else {
                        StrokeCounterCard(challenge: challenge)
                    }
                }
            }.padding(.horizontal, 16)
        }
    }

    func challengeSection(label: String, challenges: [Challenge]) -> some View {
        VStack(spacing: 0) {
            sLabel(label)
            VStack(spacing: 8) {
                ForEach(challenges) { ChallengeCard(challenge: $0) }
            }.padding(.horizontal, 16)
        }
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Text("🤷").font(.system(size: 48))
            Text("NO CHALLENGES YET").font(.system(size: 16, weight: .black)).fontWidth(.compressed).tracking(3).foregroundStyle(.white.opacity(0.25))
            Text("Be the first to talk some trash.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let challenge: Challenge
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager

    var me: Player? { authManager.currentPlayer }
    var involvesMe: Bool { challenge.involves(me?.id ?? UUID()) }

    var statusColor: Color {
        switch challenge.status {
        case .pending:          return .yellow
        case .strokesCountered: return .orange
        case .active:           return Color("DudeCupGreen")
        case .resolved:         return challenge.winnerId == me?.id.uuidString ? Color("DudeCupGreen") : .red
        case .declined:         return .white.opacity(0.3)
        case .tied:             return .white.opacity(0.5)
        }
    }

    var statusLabel: String {
        switch challenge.status {
        case .pending:          return "PENDING"
        case .strokesCountered: return "COUNTER PENDING"
        case .active:           return "LIVE"
        case .resolved:
            guard let wn = challenge.winnerName else { return "RESOLVED" }
            return "\(wn.components(separatedBy: " ").first ?? wn) WINS"
        case .declined:         return "DECLINED"
        case .tied:             return "TIE — NO ACTION"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(statusColor).frame(height: 2)
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                playersRow
                contextRow
                if let trash = challenge.trash, !trash.isEmpty {
                    Text("\"\(trash)\"").font(.system(size: 12).italic()).foregroundStyle(.white.opacity(0.4)).lineLimit(2)
                }
                if let summary = challenge.strokeSummary {
                    Text(summary).font(.system(size: 10, weight: .heavy)).tracking(1)
                        .foregroundStyle(.orange.opacity(0.8))
                }
                if challenge.status == .resolved,
                   let me, challenge.loserId(currentPlayerId: me.id) == me.id.uuidString {
                    venmoButton(to: challenge.winnerName ?? "", amount: challenge.amount,
                                note: "Dude Cup 2026 — \(challenge.type.rawValue) R\(challenge.roundNumber)")
                }
            }
            .padding(14)
        }
        .background(Color(white: 0.07)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(involvesMe ? statusColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1))
    }

    var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: challenge.type.icon).font(.system(size: 12, weight: .bold)).foregroundStyle(statusColor)
            Text(challenge.type.rawValue.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(statusColor)
            Spacer()
            Text(statusLabel).font(.system(size: 9, weight: .heavy)).tracking(2)
                .foregroundStyle(statusColor.opacity(0.8)).padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor.opacity(0.1)).clipShape(Capsule())
        }
    }

    var playersRow: some View {
        HStack(spacing: 0) {
            playerChip(name: challenge.challengerName,
                       isWinner: challenge.status == .resolved && challenge.winnerId == challenge.challengerId)
            Text("VS").font(.system(size: 11, weight: .black)).fontWidth(.compressed)
                .foregroundStyle(.white.opacity(0.3)).frame(width: 36)
            playerChip(name: challenge.challengedName,
                       isWinner: challenge.status == .resolved && challenge.winnerId == challenge.challengedId)
        }
    }

    var contextRow: some View {
        HStack(spacing: 6) {
            Text("R\(challenge.roundNumber)").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
            if let hole = challenge.holeNumber {
                Text("·").foregroundStyle(.white.opacity(0.15))
                Text("HOLE \(hole)").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
            }
            if !challenge.selectedHoles.isEmpty {
                Text("·").foregroundStyle(.white.opacity(0.15))
                Text("HOLES \(challenge.selectedHoles.sorted().map(String.init).joined(separator: ","))").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.3)).lineLimit(1)
            }
            Spacer()
            Text("$\(Int(challenge.amount))").font(.system(size: 20, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
        }
    }

    func playerChip(name: String, isWinner: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(isWinner ? Color("DudeCupGreen").opacity(0.2) : Color(white: 0.14)).frame(width: 30, height: 30)
                Text(name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined())
                    .font(.system(size: 10, weight: .black)).fontWidth(.compressed)
                    .foregroundStyle(isWinner ? Color("DudeCupGreen") : .white.opacity(0.6))
            }
            Text(name.components(separatedBy: " ").first ?? name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isWinner ? Color("DudeCupGreen") : .white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func venmoButton(to name: String, amount: Double, note: String) -> some View {
        let first = name.components(separatedBy: " ").first ?? name
        let enc = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? note
        let url = "venmo://paycharge?txn=pay&amount=\(Int(amount))&note=\(enc)"
        return Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill").font(.system(size: 14, weight: .bold))
                Text("PAY \(first.uppercased()) $\(Int(amount)) ON VENMO").font(.system(size: 11, weight: .heavy)).tracking(1)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color(red: 0.21, green: 0.56, blue: 0.98)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Pending Challenge Card

struct PendingChallengeCard: View {
    let challenge: Challenge
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore
    @State private var showCounter = false
    @State private var counterStrokes: Int = 0

    var challengerFirst: String { challenge.challengerName.components(separatedBy: " ").first ?? challenge.challengerName }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("⚡️").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(challengerFirst) challenged you!").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text("\(challenge.type.rawValue) · R\(challenge.roundNumber) · $\(Int(challenge.amount))")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
            }

            if !challenge.selectedHoles.isEmpty {
                Text("Holes: \(challenge.selectedHoles.sorted().map(String.init).joined(separator: ", "))")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            }

            if challenge.strokesOffered > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill").font(.system(size: 11)).foregroundStyle(.orange)
                    Text("\(challengerFirst) offers \(challenge.strokesOffered) stroke\(challenge.strokesOffered == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                }
            }

            if let trash = challenge.trash, !trash.isEmpty {
                Text("\"\(trash)\"").font(.system(size: 12).italic()).foregroundStyle(.white.opacity(0.4))
            }

            if showCounter {
                counterStepperView
            }

            if !showCounter {
                HStack(spacing: 8) {
                    Button {
                        Task { await bettingStore.respondToChallenge(id: challenge.id, accept: false) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("DECLINE").font(.system(size: 11, weight: .heavy)).tracking(1)
                            .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(white: 0.14)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        showCounter = true
                        counterStrokes = challenge.strokesOffered
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("COUNTER").font(.system(size: 11, weight: .heavy)).tracking(1)
                            .foregroundStyle(.orange).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
                    }

                    Button {
                        Task { await bettingStore.respondToChallenge(id: challenge.id, accept: true) }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text("ACCEPT").font(.system(size: 11, weight: .heavy)).tracking(1)
                            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color("DudeCupGreen")).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }

    var counterStepperView: some View {
        VStack(spacing: 12) {
            Text("REQUEST STROKES").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
            HStack(spacing: 24) {
                Button { if counterStrokes > 0 { counterStrokes -= 1 } } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 32))
                        .foregroundStyle(counterStrokes > 0 ? Color.orange : .white.opacity(0.15))
                }.buttonStyle(.plain)

                VStack(spacing: 2) {
                    Text("\(counterStrokes)").font(.system(size: 48, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
                    Text(counterStrokes == 1 ? "STROKE" : "STROKES").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                }.frame(minWidth: 70)

                Button { if counterStrokes < 18 { counterStrokes += 1 } } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundStyle(Color.orange)
                }.buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Button { showCounter = false } label: {
                    Text("CANCEL").font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(white: 0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    Task { await bettingStore.counterStrokeOffer(id: challenge.id, strokes: counterStrokes) }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("SEND COUNTER").font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Stroke Counter Card

struct StrokeCounterCard: View {
    let challenge: Challenge
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore

    var challengedFirst: String { challenge.challengedName.components(separatedBy: " ").first ?? challenge.challengedName }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("🔄").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(challengedFirst) countered your stroke offer").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    Text("\(challenge.type.rawValue) · R\(challenge.roundNumber) · $\(Int(challenge.amount))")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("YOU OFFERED").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                    Text("\(challenge.strokesOffered)").font(.system(size: 28, weight: .black)).fontWidth(.compressed).foregroundStyle(.white.opacity(0.4))
                    Text("STROKES").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right").foregroundStyle(.white.opacity(0.2))

                VStack(spacing: 2) {
                    Text("THEY WANT").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.orange.opacity(0.7))
                    Text("\(challenge.strokesCountered ?? 0)").font(.system(size: 28, weight: .black)).fontWidth(.compressed).foregroundStyle(.orange)
                    Text("STROKES").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.orange.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12).background(Color(white: 0.1)).clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Button {
                    Task { await bettingStore.respondToStrokeCounter(id: challenge.id, accept: false) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("DECLINE").font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color(white: 0.14)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    Task { await bettingStore.respondToStrokeCounter(id: challenge.id, accept: true) }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("ACCEPT \(challenge.strokesCountered ?? 0) STROKES").font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Issue Challenge Sheet

struct IssueChallengeSheet: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOpponent: Player? = nil
    @State private var selectedType: ChallengeType = .lowRound
    @State private var selectedRound: Int = 1
    @State private var selectedHole: Int = 1
    @State private var selectedHoles: [Int] = []
    @State private var amount: Double = 10
    @State private var showCustomAmount = false
    @State private var customAmountText: String = ""
    @State private var strokesOffered: Int = 0
    @State private var trash: String = ""
    @State private var isSubmitting = false

    var me: Player? { authManager.currentPlayer }
    var opponents: [Player] { manager.players.filter { $0.id != me?.id }.sorted { $0.name < $1.name } }

    var effectiveAmount: Double {
        showCustomAmount ? (Double(customAmountText) ?? 0) : amount
    }

    var canSubmit: Bool {
        guard selectedOpponent != nil && effectiveAmount > 0 else { return false }
        if selectedType == .pickSix && selectedHoles.count != 6 { return false }
        return true
    }

    var suggested: Int {
        guard let opp = selectedOpponent else { return 0 }
        return bettingStore.suggestedStrokes(challengerId: me?.id ?? UUID(), challengedId: opp.id)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        opponentPicker
                        typePicker
                        whenPicker
                        if selectedType == .pickSix { holeGrid }
                        stakesPicker
                        strokesSection
                        trashField
                        submitButton
                    }
                }
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("Issue Challenge").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.foregroundStyle(.white.opacity(0.5))
                    }
                }
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
    }

    var opponentPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("CHALLENGE WHO?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(opponents) { opponentChip($0) }
                }.padding(.horizontal, 16)
            }
        }
    }

    var typePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("BET TYPE")
            VStack(spacing: 0) {
                ForEach(Array(ChallengeType.allCases.enumerated()), id: \.element) { idx, type in
                    typeRow(type: type, isLast: idx == ChallengeType.allCases.count - 1)
                }
            }
            .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
        }
    }

    var whenPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("WHEN")
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ROUND").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                    Picker("", selection: $selectedRound) {
                        ForEach(1...4, id: \.self) { Text("Round \($0)").tag($0) }
                    }
                    .pickerStyle(.menu).tint(Color("DudeCupGreen"))
                    .padding(10).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if selectedType == .lowHole {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HOLE").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                        Picker("", selection: $selectedHole) {
                            ForEach(1...18, id: \.self) { Text("Hole \($0)").tag($0) }
                        }
                        .pickerStyle(.menu).tint(Color("DudeCupGreen"))
                        .padding(10).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    var holeGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("SELECT 6 HOLES")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(1...18, id: \.self) { hole in
                    let isSelected = selectedHoles.contains(hole)
                    let isDisabled = !isSelected && selectedHoles.count >= 6
                    Button {
                        toggleHole(hole)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(hole)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(isSelected ? .black : isDisabled ? .white.opacity(0.2) : .white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(isSelected ? Color("DudeCupGreen") : Color(white: 0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain).disabled(isDisabled)
                }
            }
            .padding(.horizontal, 16)
            Text("\(selectedHoles.count) / 6 holes selected")
                .font(.system(size: 10, weight: .heavy)).tracking(2)
                .foregroundStyle(selectedHoles.count == 6 ? Color("DudeCupGreen") : .white.opacity(0.3))
                .padding(.horizontal, 20).padding(.top, 10)
        }
    }

    var stakesPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("STAKES")
            HStack(spacing: 8) {
                ForEach([5.0, 10.0, 20.0], id: \.self) { amt in
                    Button {
                        amount = amt; showCustomAmount = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("$\(Int(amt))").font(.system(size: 14, weight: .heavy)).fontWidth(.compressed)
                            .foregroundStyle(!showCustomAmount && amount == amt ? .black : .white.opacity(0.6))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(!showCustomAmount && amount == amt ? Color.orange : Color(white: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
                Button {
                    showCustomAmount = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("OTHER").font(.system(size: 12, weight: .heavy)).fontWidth(.compressed)
                        .foregroundStyle(showCustomAmount ? .black : .white.opacity(0.6))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(showCustomAmount ? Color.orange : Color(white: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if showCustomAmount {
                HStack(spacing: 10) {
                    Text("$").font(.system(size: 24, weight: .black)).foregroundStyle(Color.orange)
                    TextField("Enter amount", text: $customAmountText)
                        .font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                        .keyboardType(.numberPad)
                }
                .padding(14).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 10)
            }
        }
    }

    var strokesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("STROKES OFFERED")
            VStack(spacing: 10) {
                if let opp = selectedOpponent, suggested > 0 {
                    Button { strokesOffered = suggested } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars").font(.system(size: 11))
                            Text("Suggested: \(suggested) strokes based on handicap difference")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color("DudeCupGreen").opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    }.buttonStyle(.plain)
                }

                HStack(spacing: 28) {
                    Button { if strokesOffered > 0 { strokesOffered -= 1 } } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 36))
                            .foregroundStyle(strokesOffered > 0 ? Color.orange : .white.opacity(0.1))
                    }.buttonStyle(.plain)

                    VStack(spacing: 2) {
                        Text("\(strokesOffered)").font(.system(size: 56, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
                        Text(strokesOffered == 1 ? "STROKE" : "STROKES").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                    }.frame(minWidth: 80)

                    Button { if strokesOffered < 18 { strokesOffered += 1 } } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 36)).foregroundStyle(Color.orange)
                    }.buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                Group {
                    if strokesOffered > 0, let opp = selectedOpponent {
                        Text("You give \(opp.name.components(separatedBy: " ").first ?? opp.name) \(strokesOffered) stroke\(strokesOffered == 1 ? "" : "s")")
                            .foregroundStyle(Color.orange.opacity(0.8))
                    } else {
                        Text("No strokes — straight up").foregroundStyle(.white.opacity(0.2))
                    }
                }
                .font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    var trashField: some View {
        VStack(alignment: .leading, spacing: 0) {
            sLabel("TRASH TALK (OPTIONAL)")
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.08))
                if trash.isEmpty {
                    Text("Say something. Everyone will see it.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.2)).padding(14)
                }
                TextEditor(text: $trash)
                    .font(.system(size: 13)).foregroundStyle(.white)
                    .scrollContentBackground(.hidden).background(Color.clear)
                    .padding(10).frame(minHeight: 80)
            }
            .padding(.horizontal, 16)
        }
    }

    var submitButton: some View {
        Button { submit() } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(.black).scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.fill").font(.system(size: 14, weight: .bold))
                }
                Text(isSubmitting ? "SENDING…" : "SEND CHALLENGE").font(.system(size: 14, weight: .heavy)).tracking(1)
            }
            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(canSubmit ? Color.orange : Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit || isSubmitting)
        .padding(.horizontal, 16).padding(.top, 28).padding(.bottom, 40)
    }

    func opponentChip(_ player: Player) -> some View {
        let selected = selectedOpponent?.id == player.id
        return Button {
            selectedOpponent = player
            strokesOffered = bettingStore.suggestedStrokes(challengerId: me?.id ?? UUID(), challengedId: player.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(selected ? Color.orange : Color(white: 0.14)).frame(width: 46, height: 46)
                    Text(player.name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined())
                        .font(.system(size: 14, weight: .black)).fontWidth(.compressed)
                        .foregroundStyle(selected ? .black : .white.opacity(0.7))
                }
                Text(player.name.components(separatedBy: " ").first ?? player.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selected ? Color.orange : .white.opacity(0.5))
            }
        }.buttonStyle(.plain)
    }

    func typeRow(type: ChallengeType, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                selectedType = type
                if type != .pickSix { selectedHoles = [] }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: type.icon).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedType == type ? Color("DudeCupGreen") : .white.opacity(0.4))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.rawValue.uppercased()).font(.system(size: 13, weight: .heavy)).fontWidth(.compressed)
                            .foregroundStyle(selectedType == type ? Color("DudeCupGreen") : .white)
                        Text(type.description).font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                    if selectedType == type {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color("DudeCupGreen"))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(selectedType == type ? Color("DudeCupGreen").opacity(0.06) : Color.clear)
            }.buttonStyle(.plain)
            if !isLast { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 52) }
        }
    }

    func toggleHole(_ hole: Int) {
        if let i = selectedHoles.firstIndex(of: hole) {
            selectedHoles.remove(at: i)
        } else if selectedHoles.count < 6 {
            selectedHoles.append(hole)
        }
    }

    func submit() {
        guard let me, let opponent = selectedOpponent, canSubmit else { return }
        isSubmitting = true
        let challenge = Challenge(
            id: nil, // Firebase generates the ID automatically
            challengerId: me.id.uuidString, challengerName: me.name,
            challengedId: opponent.id.uuidString, challengedName: opponent.name,
            type: selectedType, roundNumber: selectedRound,
            holeNumber: selectedType == .lowHole ? selectedHole : nil,
            selectedHoles: selectedType == .pickSix ? selectedHoles.sorted() : [],
            amount: effectiveAmount,
            trash: trash.isEmpty ? nil : trash,
            strokesOffered: strokesOffered,
            strokesCountered: nil,
            strokesAccepted: 0,
            status: .pending,
            createdAt: nil
        )
        Task {
            await bettingStore.issueChallenge(challenge)
            await MainActor.run { isSubmitting = false; dismiss() }
        }
    }
}
