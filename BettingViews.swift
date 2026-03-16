//
//  BettingViews.swift
//  The Rug
//

import SwiftUI

private func bLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .heavy)).tracking(4)
        .foregroundStyle(Color("DudeCupGreen")).padding(.bottom, 10)
}

private func betEmoji(_ type: BetType) -> String {
    switch type { case .tournamentPurse: return "🏆"; case .closestToPin: return "🎯"; case .random9: return "🎲"; case .deuces: return "2️⃣"; case .skins: return "💰" }
}

struct BettingView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(BettingStore.self) private var bettingStore
    @Environment(AuthManager.self) private var authManager
    
    var currentPlayer: Player? { authManager.currentPlayer }
    
    var totalPot: Double {
        bettingStore.bets.reduce(0) { total, bet in
            guard let betId = bet.id else { return total }
            let count = Double(bettingStore.betEntries.filter { $0.betId == betId && $0.status == .paid }.count)
            return total + bet.amount * count
        }
    }
    
    func entryStatus(for bet: Bet) -> BetStatus {
        guard let player = currentPlayer, let betId = bet.id else { return .notEntered }
        return bettingStore.betEntries.first(where: { $0.playerId == player.id.uuidString && $0.betId == betId })?.status ?? .notEntered
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    potHero("TOTAL TOURNAMENT POT", totalPot)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            bLabel("AVAILABLE BETS")
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                        
                        VStack(spacing: 10) {
                            ForEach(bettingStore.bets) { bet in
                                NavigationLink(destination: destinationView(for: bet)) {
                                    BetCardRow(bet: bet, status: entryStatus(for: bet))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 16)
                    }
                    
                    BettingRosterView().padding(.top, 32)
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    @ViewBuilder
    func destinationView(for bet: Bet) -> some View {
        switch bet.type {
        case .tournamentPurse: TournamentPurseView(bet: bet)
        case .closestToPin: ClosestToPinView(bet: bet)
        case .random9: Random9View(bet: bet)
        case .deuces: DeucesView(bet: bet)
        case .skins: SkinsView(bet: bet)
        }
    }
    
    struct BetCardRow: View {
        let bet: Bet
        let status: BetStatus
        var statusColor: Color {
            switch status { case .notEntered: return .white.opacity(0.15); case .entered: return .orange; case .paymentPending: return .yellow; case .paid: return Color("DudeCupGreen") }
        }
        var statusLabel: String {
            switch status { case .notEntered: return "ENTER"; case .entered: return "ENTERED"; case .paymentPending: return "PENDING"; case .paid: return "PAID ✓" }
        }
        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("DudeCupGreen").opacity(status == .paid ? 0.2 : 0.08))
                        .frame(width: 52, height: 52)
                    Text(betEmoji(bet.type)).font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.type.rawValue.uppercased())
                        .font(.system(size: 14, weight: .heavy)).fontWidth(.compressed).tracking(0.5).foregroundStyle(.white)
                    Text("$\(Int(bet.amount)) ENTRY")
                        .font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusLabel).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(statusColor)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.15))
                }
            }
            .padding(14).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(status == .paid ? Color("DudeCupGreen").opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1))
        }
    }
    
    struct TournamentPurseView: View {
        let bet: Bet
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        
        var totalPot: Double {
            guard let betId = bet.id else { return 0 }
            return bet.amount * Double(bettingStore.betEntries.filter { $0.betId == betId && $0.status == .paid }.count)
        }
        var payouts: [(String, Double)] { [("1ST PLACE", totalPot * 0.5), ("2ND PLACE", totalPot * 0.3), ("3RD PLACE", totalPot * 0.2)] }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        potHero("TOURNAMENT POT", totalPot)
                        VStack(alignment: .leading, spacing: 0) {
                            bLabel("ABOUT").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            Text(bet.description).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                                .padding(16).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                            bLabel("PAYOUT STRUCTURE").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(payouts.enumerated()), id: \.offset) { i, p in
                                    HStack {
                                        Text(p.0).font(.system(size: 14, weight: .heavy)).fontWidth(.compressed).foregroundStyle(.white)
                                        Spacer()
                                        Text("$\(Int(p.1))").font(.system(size: 24, weight: .black)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                                    }.padding(.horizontal, 16).padding(.vertical, 16)
                                    if i < payouts.count - 1 { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16) }
                                }
                            }.background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Tournament Purse").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    struct ClosestToPinView: View {
        let bet: Bet
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        
        var totalEntries: Int {
            guard let betId = bet.id else { return 0 }
            return bettingStore.betEntries.filter { $0.betId == betId && $0.status == .paid }.count
        }
        var potPerContest: Double { 10.0 * Double(totalEntries) }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        potHero("EACH CONTEST POT", potPerContest, sub: "\(totalEntries) entries × $10")
                        VStack(alignment: .leading, spacing: 0) {
                            bLabel("ABOUT").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            Text(bet.description).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                                .padding(16).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                            bLabel("CONTESTS").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            VStack(spacing: 8) {
                                ForEach(bettingStore.ctpContests) { contest in
                                    NavigationLink(destination: CTPContestDetailView(contest: contest, potPerContest: potPerContest)) {
                                        CTPContestCard(contest: contest, potPerContest: potPerContest)
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, 16)
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Closest to Pin").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    struct CTPContestCard: View {
        let contest: CTPContest
        let potPerContest: Double
        @Environment(TournamentManager.self) private var manager
        
        var leader: (player: Player, entry: CTPEntry)? {
            guard let w = contest.winnerEntry, let p = manager.players.first(where: { $0.id.uuidString == w.playerId }) else { return nil }
            return (p, w)
        }
        
        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color("DudeCupGreen").opacity(0.1)).frame(width: 44, height: 44)
                    Text("🎯").font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("ROUND \(contest.round) · HOLE \(contest.hole)")
                        .font(.system(size: 13, weight: .heavy)).fontWidth(.compressed).foregroundStyle(.white)
                    if let l = leader {
                        HStack(spacing: 4) {
                            Text("👑").font(.system(size: 11))
                            Text("\(l.player.name)  \(l.entry.displayDistance)")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                        }
                    } else {
                        Text("No entries yet").font(.system(size: 11)).foregroundStyle(.white.opacity(0.2))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(potPerContest))").font(.system(size: 18, weight: .black)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                    if contest.isClosed { Text("CLOSED").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.red.opacity(0.7)) }
                }
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.white.opacity(0.15))
            }
            .padding(14).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
        }
    }
    
    struct CTPContestDetailView: View {
        let contest: CTPContest
        let potPerContest: Double
        @Environment(TournamentManager.self) private var manager
        @State private var showingSubmission = false
        
        var sortedEntries: [(player: Player, entry: CTPEntry)] {
            contest.entries.compactMap { e in
                guard let p = manager.players.first(where: { $0.id.uuidString == e.playerId }) else { return nil }
                return (p, e)
            }.sorted { $0.entry.totalInches < $1.entry.totalInches }
        }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        ZStack {
                            Color.black
                            RadialGradient(colors: [Color("DudeCupGreen").opacity(0.12), Color.clear], center: .top, startRadius: 0, endRadius: 180)
                            VStack(spacing: 4) {
                                Text("ROUND \(contest.round) · \(contest.courseName.uppercased())")
                                    .font(.system(size: 9, weight: .heavy)).tracking(4).foregroundStyle(.white.opacity(0.3)).padding(.top, 24)
                                Text("HOLE \(contest.hole)").font(.system(size: 72, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
                                Text("$\(Int(potPerContest)) POT").font(.system(size: 13, weight: .heavy)).tracking(4)
                                    .foregroundStyle(Color("DudeCupGreen")).padding(.bottom, 24)
                            }
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            if let winner = sortedEntries.first {
                                VStack(alignment: .leading, spacing: 10) {
                                    bLabel("BEAT THIS").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                                    HStack(spacing: 14) {
                                        Text("👑").font(.system(size: 32))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(winner.player.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                            Text(winner.entry.displayDistance).font(.system(size: 28, weight: .black)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                                        }
                                        Spacer()
                                    }
                                    .padding(16).background(Color("DudeCupGreen").opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color("DudeCupGreen").opacity(0.2), lineWidth: 1))
                                    .padding(.horizontal, 16)
                                }
                            }
                            Button { showingSubmission = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("SUBMIT RESULT").font(.system(size: 13, weight: .heavy)).tracking(1)
                                }
                                .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color("DudeCupGreen")).clipShape(RoundedRectangle(cornerRadius: 12))
                            }.padding(.horizontal, 16).padding(.top, 20)
                            
                            if !sortedEntries.isEmpty {
                                bLabel("LEADERBOARD").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                                VStack(spacing: 0) {
                                    ForEach(Array(sortedEntries.enumerated()), id: \.offset) { i, item in
                                        HStack {
                                            Text("\(i + 1)").font(.system(size: 14, weight: .black)).fontWidth(.compressed)
                                                .foregroundStyle(i == 0 ? Color("DudeCupGreen") : .white.opacity(0.25)).frame(width: 28)
                                            Text(item.player.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                            Spacer()
                                            Text(item.entry.displayDistance).font(.system(size: 18, weight: .black)).fontWidth(.compressed)
                                                .foregroundStyle(i == 0 ? Color("DudeCupGreen") : .white.opacity(0.6))
                                        }.padding(.horizontal, 16).padding(.vertical, 14)
                                        if i < sortedEntries.count - 1 { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 44) }
                                    }
                                }.background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                            }
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("CTP · R\(contest.round) H\(contest.hole)").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingSubmission) { CTPSubmissionView(contest: contest) }
        }
    }
    
    struct CTPSubmissionView: View {
        let contest: CTPContest
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        @Environment(\.dismiss) private var dismiss
        @State private var selectedPlayer: Player?
        @State private var feet = ""
        @State private var inches = ""
        
        var isValid: Bool { selectedPlayer != nil && !feet.isEmpty && !inches.isEmpty }
        
        var body: some View {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            bLabel("PLAYER").padding(.horizontal, 4)
                            Picker("Select Player", selection: $selectedPlayer) {
                                Text("Select...").tag(nil as Player?)
                                ForEach(manager.players) { p in Text(p.name).tag(p as Player?) }
                            }
                            .pickerStyle(.menu)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            bLabel("DISTANCE").padding(.horizontal, 4)
                            HStack(spacing: 12) {
                                HStack {
                                    TextField("0", text: $feet).keyboardType(.numberPad).font(.system(size: 24, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
                                    Text("FT").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                                }.padding(14).background(Color(white: 0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
                                HStack {
                                    TextField("0", text: $inches).keyboardType(.numberPad).font(.system(size: 24, weight: .black)).fontWidth(.compressed).foregroundStyle(.white)
                                    Text("IN").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.3))
                                }.padding(14).background(Color(white: 0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        Spacer()
                    }.padding(20)
                }
                .navigationTitle("Submit CTP Result").navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(.white.opacity(0.5)) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            if let p = selectedPlayer, let f = Int(feet), let i = Int(inches) {
                                Task { await bettingStore.submitCTPEntry(contestId: contest.id, playerId: p.id, feet: f, inches: i); dismiss() }
                            }
                        }
                        .disabled(!isValid)
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(isValid ? Color("DudeCupGreen") : .white.opacity(0.2))
                    }
                }
            }
        }
    }
    
    struct Random9View: View {
        let bet: Bet
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        
        var totalEntries: Int {
            guard let betId = bet.id else { return 0 }
            return bettingStore.betEntries.filter { $0.betId == betId && $0.status == .paid }.count
        }
        var totalPot: Double { bet.amount * Double(totalEntries) }
        
        var sortedHoles: [Random9Hole] {
            guard let sel = bettingStore.random9Selection else { return [] }
            return sel.holes.sorted { lhs, rhs in lhs.round != rhs.round ? lhs.round < rhs.round : lhs.hole < rhs.hole }
        }
        
        var leaderboard: [(player: Player, score: Int)] {
            manager.players.compactMap { p in
                guard let s = bettingStore.random9Score(for: p.id) else { return nil }
                return (p, s)
            }.sorted { $0.score < $1.score }
        }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        potHero("RANDOM 9 POT", totalPot, sub: "\(totalEntries) entries × $\(Int(bet.amount))")
                        VStack(alignment: .leading, spacing: 0) {
                            bLabel("ABOUT").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            Text(bet.description).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                                .padding(16).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                            
                            if bettingStore.random9Selection != nil {
                                bLabel("SELECTED HOLES").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                    ForEach(Array(sortedHoles.enumerated()), id: \.offset) { _, hole in
                                        VStack(spacing: 3) {
                                            Text("R\(hole.round) · H\(hole.hole)").font(.system(size: 13, weight: .heavy)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                                            Text(hole.round <= 2 ? "Canyon" : "Mountain").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.white.opacity(0.25))
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(Color("DudeCupGreen").opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }.padding(.horizontal, 16)
                                
                                if !leaderboard.isEmpty {
                                    bLabel("LEADERBOARD").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                                    VStack(spacing: 0) {
                                        ForEach(Array(leaderboard.enumerated()), id: \.offset) { i, item in
                                            NavigationLink { Random9ScorecardView(player: item.player, totalScore: item.score) } label: {
                                                HStack {
                                                    Text("\(i + 1)").font(.system(size: 14, weight: .black)).fontWidth(.compressed)
                                                        .foregroundStyle(i == 0 ? Color("DudeCupGreen") : .white.opacity(0.25)).frame(width: 28)
                                                    Text(item.player.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                                    Spacer()
                                                    Text("\(item.score)").font(.system(size: 22, weight: .black)).fontWidth(.compressed)
                                                        .foregroundStyle(i == 0 ? Color("DudeCupGreen") : .white.opacity(0.6))
                                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.white.opacity(0.15))
                                                }.padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
                                            }.buttonStyle(.plain)
                                            if i < leaderboard.count - 1 { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 44) }
                                        }
                                    }.background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                                }
                            } else {
                                Button { bettingStore.generateRandom9() } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "dice.fill")
                                        Text("GENERATE RANDOM 9").font(.system(size: 13, weight: .heavy)).tracking(1)
                                    }
                                    .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(Color("DudeCupGreen")).clipShape(RoundedRectangle(cornerRadius: 12))
                                }.padding(.horizontal, 16).padding(.top, 28)
                            }
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Random 9").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    struct Random9ScorecardView: View {
        let player: Player
        let totalScore: Int
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        
        var holeDetails: [(hole: Random9Hole, strokes: Int, par: Int)] {
            guard let sel = bettingStore.random9Selection,
                  let ps = manager.scores.first(where: { $0.playerId == player.id }) else { return [] }
            return sel.holes.compactMap { r9 in
                guard let round = ps.rounds.first(where: { $0.roundNumber == r9.round }),
                      r9.hole <= round.holes.count,
                      let course = manager.courses.first(where: { $0.id == round.courseId }),
                      let ch = course.holes.first(where: { $0.number == r9.hole }) else { return nil }
                return (r9, round.holes[r9.hole - 1].strokes, ch.par)
            }.sorted { lhs, rhs in lhs.hole.round != rhs.hole.round ? lhs.hole.round < rhs.hole.round : lhs.hole.hole < rhs.hole.hole }
        }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        potHero(player.name.uppercased(), Double(totalScore), sub: "TOTAL GROSS SCORE", isMoney: false)
                        VStack(alignment: .leading, spacing: 0) {
                            bLabel("SCORECARD").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(holeDetails.enumerated()), id: \.offset) { i, d in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("R\(d.hole.round) · HOLE \(d.hole.hole)").font(.system(size: 13, weight: .heavy)).fontWidth(.compressed).foregroundStyle(.white)
                                            Text("PAR \(d.par)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(d.strokes)").font(.system(size: 28, weight: .black)).fontWidth(.compressed)
                                                .foregroundStyle(scoreColor(d.strokes, d.par))
                                            Text(scoreLabel(d.strokes, d.par)).font(.system(size: 9, weight: .heavy)).tracking(1)
                                                .foregroundStyle(.white.opacity(0.25))
                                        }
                                    }.padding(.horizontal, 16).padding(.vertical, 14)
                                    if i < holeDetails.count - 1 { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16) }
                                }
                            }.background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Random 9 Detail").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        }
        
        func scoreColor(_ s: Int, _ par: Int) -> Color {
            let d = s - par
            if d <= -2 { return Color(red:0.3,green:0.7,blue:1) }
            if d == -1 { return Color("DudeCupGreen") }
            if d == 0  { return .white }
            if d == 1  { return Color(red:1,green:0.85,blue:0.3) }
            return Color(red:1,green:0.35,blue:0.35)
        }
        func scoreLabel(_ s: Int, _ par: Int) -> String {
            switch s - par { case ..<(-2): return "ALBATROSS"; case -2: return "EAGLE"; case -1: return "BIRDIE"; case 0: return "PAR"; case 1: return "BOGEY"; case 2: return "DOUBLE"; default: return "+\(s-par)" }
        }
    }
    
    struct DeucesView: View {
        let bet: Bet
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        
        var totalEntries: Int {
            guard let betId = bet.id else { return 0 }
            return bettingStore.betEntries.filter { $0.betId == betId && $0.status == .paid }.count
        }
        var totalPot: Double { bet.amount * Double(totalEntries) }
        
        var par3Holes: [(round: Int, hole: Int, course: String)] {
            [(1,5,"Canyon"),(1,8,"Canyon"),(1,13,"Canyon"),(1,16,"Canyon"),
             (2,3,"Mountain"),(2,6,"Mountain"),(2,14,"Mountain"),(2,16,"Mountain"),
             (3,5,"Canyon"),(3,8,"Canyon"),(3,13,"Canyon"),(3,16,"Canyon"),
             (4,3,"Mountain"),(4,6,"Mountain"),(4,14,"Mountain"),(4,16,"Mountain")]
        }
        
        struct DeuceResult {
            let player: Player
            let deuces: [(round: Int, hole: Int)]
        }
        
        var deucesResults: [DeuceResult] {
            let unsorted: [DeuceResult] = manager.players.compactMap { player in
                guard let score = manager.scores.first(where: { $0.playerId == player.id }) else { return nil }
                let found: [(round: Int, hole: Int)] = par3Holes.compactMap { p3 in
                    guard let round = score.rounds.first(where: { $0.roundNumber == p3.round }),
                          p3.hole <= round.holes.count,
                          round.holes[p3.hole - 1].strokes == 2 else { return nil }
                    return (p3.round, p3.hole)
                }
                return found.isEmpty ? nil : DeuceResult(player: player, deuces: found)
            }
            return unsorted.sorted { $0.deuces.count > $1.deuces.count }
        }
        
        var payoutPerWinner: Double { deucesResults.isEmpty ? 0 : totalPot / Double(deucesResults.count) }
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        potHero("DEUCES POT", totalPot, sub: deucesResults.isEmpty ? "\(totalEntries) entries" : "\(deucesResults.count) winner\(deucesResults.count == 1 ? "" : "s") · $\(Int(payoutPerWinner)) each")
                        VStack(alignment: .leading, spacing: 0) {
                            bLabel("ABOUT").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                            Text(bet.description).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
                                .padding(16).background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                            
                            if !deucesResults.isEmpty {
                                bLabel("IN THE POT").padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 4)
                                VStack(spacing: 0) {
                                    ForEach(Array(deucesResults.enumerated()), id: \.offset) { i, r in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text(r.player.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("$\(Int(payoutPerWinner))").font(.system(size: 22, weight: .black)).fontWidth(.compressed).foregroundStyle(Color("DudeCupGreen"))
                                                    Text("\(r.deuces.count) DEUCE\(r.deuces.count == 1 ? "" : "S")").font(.system(size: 8, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.25))
                                                }
                                            }
                                            HStack(spacing: 6) {
                                                ForEach(Array(r.deuces.enumerated()), id: \.offset) { _, d in
                                                    Text("R\(d.0) H\(d.1)").font(.system(size: 9, weight: .heavy)).tracking(1)
                                                        .foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 4)
                                                        .background(Color("DudeCupGreen")).clipShape(Capsule())
                                                }
                                            }
                                        }.padding(.horizontal, 16).padding(.vertical, 14)
                                        if i < deucesResults.count - 1 { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 16) }
                                    }
                                }.background(Color(white: 0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 10) {
                                    Text("2️⃣").font(.system(size: 48))
                                    Text("NO DEUCES YET").font(.system(size: 14, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.2))
                                    Text("Score a 2 on any par 3 to get in the pot.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.15))
                                }.frame(maxWidth: .infinity).padding(.vertical, 60)
                            }
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Deuces").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    struct BettingRosterView: View {
        @Environment(TournamentManager.self) private var manager
        @Environment(BettingStore.self) private var bettingStore
        @Environment(AuthManager.self) private var authManager
        
        var betIcons: [(id: String?, icon: String)] {
            bettingStore.bets.map { ($0.id, betEmoji($0.type)) }
        }
        
        func paymentStatus(playerId: UUID, betId: String?) -> BetStatus {
            guard let betId = betId else { return .notEntered }
            return bettingStore.betEntries.first(where: { $0.playerId == playerId.uuidString && $0.betId == betId })?.status ?? .notEntered
        }
        
        var totalCollected: Double {
            bettingStore.betEntries.filter { $0.status == .paid }.reduce(0) { sum, entry in
                sum + (bettingStore.bets.first(where: { $0.id == entry.betId })?.amount ?? 0)
            }
        }
        var totalPossible: Double { Double(manager.players.count) * bettingStore.bets.reduce(0) { $0 + $1.amount } }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    bLabel("BETTING ROSTER")
                    Spacer()
                    Text("$\(Int(totalCollected)) / $\(Int(totalPossible))")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color("DudeCupGreen"))
                }.padding(.horizontal, 20).padding(.bottom, 10)
                
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("PLAYER").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 16)
                        ForEach(betIcons, id: \.id) { b in
                            Text(b.icon).font(.system(size: 18)).frame(width: 48)
                        }
                    }.padding(.vertical, 12).background(Color(white: 0.1))
                    
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(manager.players) { player in
                                HStack(spacing: 0) {
                                    Text(player.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 16)
                                    ForEach(betIcons, id: \.id) { b in
                                        Button {
                                            if authManager.currentPlayer?.name == "Andrew H." {
                                                bettingStore.toggleBetStatus(playerId: player.id, betId: b.id)
                                            }
                                        } label: {
                                            rosterIcon(paymentStatus(playerId: player.id, betId: b.id))
                                        }.frame(width: 48)
                                    }
                                }.padding(.vertical, 11)
                                Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1).padding(.leading, 16)
                            }
                        }
                    }.frame(height: 380)
                }
                .background(Color(white: 0.07)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
            }
        }
        
        @ViewBuilder
        func rosterIcon(_ status: BetStatus) -> some View {
            switch status {
            case .notEntered: Circle().fill(Color.white.opacity(0.07)).frame(width: 20, height: 20)
            case .entered, .paymentPending: Circle().fill(Color.orange.opacity(0.6)).frame(width: 20, height: 20)
            case .paid:
                ZStack {
                    Circle().fill(Color("DudeCupGreen").opacity(0.2)).frame(width: 20, height: 20)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .black)).foregroundStyle(Color("DudeCupGreen"))
                }
            }
        }
    }
}

// MARK: - Shared pot hero view

private func potHero(_ label: String, _ amount: Double, sub: String? = nil, isMoney: Bool = true) -> some View {
    ZStack {
        Color.black
        RadialGradient(colors: [Color("DudeCupGreen").opacity(0.15), Color.clear], center: .top, startRadius: 0, endRadius: 200)
        VStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .heavy)).tracking(5).foregroundStyle(Color("DudeCupGreen")).padding(.top, 28)
            Text(isMoney ? "$\(Int(amount))" : "\(Int(amount))")
                .font(.system(size: 72, weight: .black)).fontWidth(.compressed).tracking(-2).foregroundStyle(.white)
            if let sub = sub {
                Text(sub.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.25)).padding(.bottom, 28)
            } else {
                Spacer().frame(height: 28)
            }
        }
    }
}
