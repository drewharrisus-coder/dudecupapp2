import Foundation
import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
class BettingStore {
    // MARK: - State
    var bets: [Bet] = []
    var betEntries: [PlayerBetEntry] = []
    var ctpContests: [CTPContest] = []
    var random9Selection: Random9Selection?
    var challenges: [Challenge] = []
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    // MARK: - Lifecycle Management
    
    /// Call this when the app enters the foreground or when the user authenticates
    func startListening() {
        // Prevent duplicate listeners
        guard listeners.isEmpty else { return }
        
        setupBetsListener()
        setupBetEntriesListener()
        setupCTPListener()
        setupRandom9Listener()
        setupChallengesListener()
    }
    
    /// Call this when the app backgrounds or logs out to save battery and Firebase reads
    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Listeners
    
    private func setupBetsListener() {
        let listener = db.collection("bets").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to bets: \(error)"); return }
            
            // 🔥 Magic happens here: Automatic decoding!
            guard let documents = snapshot?.documents else { return }
            self.bets = documents.compactMap { try? $0.data(as: Bet.self) }
        }
        listeners.append(listener)
    }
    
    private func setupBetEntriesListener() {
        let listener = db.collection("betEntries").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to bet entries: \(error)"); return }
            
            guard let documents = snapshot?.documents else { return }
            self.betEntries = documents.compactMap { try? $0.data(as: PlayerBetEntry.self) }
            print("✅ Live updated \(self.betEntries.count) bet entries")
        }
        listeners.append(listener)
    }
    
    private func setupCTPListener() {
        let listener = db.collection("ctpContests").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to CTP: \(error)"); return }
            
            guard let documents = snapshot?.documents else { return }
            self.ctpContests = documents.compactMap { try? $0.data(as: CTPContest.self) }
        }
        listeners.append(listener)
    }
    
    private func setupRandom9Listener() {
        let listener = db.collection("random9").document("current").addSnapshotListener { [weak self] document, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to Random 9: \(error)"); return }
            
            self.random9Selection = try? document?.data(as: Random9Selection.self)
        }
        listeners.append(listener)
    }
    
    private func setupChallengesListener() {
        // Querying for active challenges based on your tournament logic
        let listener = db.collection("challenges")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to challenges: \(error)"); return }
            
            guard let documents = snapshot?.documents else { return }
            self.challenges = documents.compactMap { try? $0.data(as: Challenge.self) }
        }
        listeners.append(listener)
    }
    
    // MARK: - 🌉 Temporary Bridge
        // We will use this to access players and scores for calculations until we build the ScoringStore
        private var players: [Player] { TournamentManager.shared.players }
        private var scores: [Score] { TournamentManager.shared.scores }

        // MARK: - 💰 Betting & CTP Actions
        
        func toggleBetStatus(playerId: UUID, betId: UUID) {
            // Find existing entry or create a new one
            let existing = betEntries.first(where: { $0.playerId == playerId.uuidString && $0.betId == betId.uuidString })
            
            let newStatus: BetStatus = (existing?.status == .paid) ? .notEntered : .paid
            let docId = existing?.id ?? UUID().uuidString
            
            let data: [String: Any] = [
                "playerId": playerId.uuidString,
                "betId": betId.uuidString,
                "status": newStatus.rawValue,
                "paidAt": newStatus == .paid ? FieldValue.serverTimestamp() : NSNull()
            ]
            
            db.collection("betEntries").document(docId).setData(data, merge: true)
        }

        func submitCTPEntry(contestId: UUID, playerId: UUID, feet: Int, inches: Int) async {
            let entryId = UUID().uuidString
            let newEntry: [String: Any] = [
                "id": entryId,
                "playerId": playerId.uuidString,
                "feet": feet,
                "inches": inches
            ]
            
            do {
                try await db.collection("ctpContests").document(contestId.uuidString).updateData([
                    "entries": FieldValue.arrayUnion([newEntry])
                ])
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } catch {
                print("❌ Failed to submit CTP: \(error.localizedDescription)")
            }
        }

        // MARK: - 🎲 Random 9 Actions
        
        func generateRandom9() {
            // Generate 9 random holes across the available rounds
            var selectedHoles: [Random9Hole] = []
            while selectedHoles.count < 9 {
                let randomRound = Int.random(in: 1...4)
                let randomHole = Int.random(in: 1...18)
                let newHole = Random9Hole(round: randomRound, hole: randomHole)
                
                if !selectedHoles.contains(where: { $0.round == randomRound && $0.hole == randomHole }) {
                    selectedHoles.append(newHole)
                }
            }
            
            let selection = Random9Selection(holes: selectedHoles, generatedAt: nil)
            try? db.collection("random9").document("current").setData(from: selection)
        }

        func random9Score(for playerId: UUID) -> Int? {
            guard let selection = random9Selection,
                  let playerScore = scores.first(where: { $0.playerId == playerId }) else { return nil }
            
            var total = 0
            for r9Hole in selection.holes {
                guard let round = playerScore.rounds.first(where: { $0.roundNumber == r9Hole.round }),
                      r9Hole.hole <= round.holes.count else { return nil } // Round not played yet
                total += round.holes[r9Hole.hole - 1].strokes
            }
            return total
        }

        // MARK: - 💵 Skins Logic
        
        func isEnteredSkins(playerId: UUID, round: Int) -> Bool {
            // Assuming there is a specific Bet ID for Skins per round, or a general Skins bet
            guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return false }
            return betEntries.contains(where: { $0.playerId == playerId.uuidString && $0.betId == skinsBet.id && $0.status == .paid })
        }

        func enterSkins(playerId: UUID, round: Int) {
            guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return }
            let docId = UUID().uuidString
            let data: [String: Any] = [
                "playerId": playerId.uuidString,
                "betId": skinsBet.id ?? "",
                "status": BetStatus.paid.rawValue,
                "paidAt": FieldValue.serverTimestamp()
            ]
            db.collection("betEntries").document(docId).setData(data, merge: true)
        }

        func skinsEntrants(for round: Int) -> [Player] {
            guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return [] }
            let entrantIds = betEntries.filter { $0.betId == skinsBet.id && $0.status == .paid }.map { $0.playerId }
            return players.filter { entrantIds.contains($0.id.uuidString) }
        }

        func skinsPot(for round: Int) -> Double {
            guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return 0 }
            return Double(skinsEntrants(for: round).count) * skinsBet.amount
        }

        func skinsWinners(for round: Int) -> [Player] {
            // Placeholder for gross birdie/eagle evaluation logic.
            // Needs the ScoringStore built to evaluate hole-by-hole minimums.
            return []
        }

        func skinsPayoutPerWinner(for round: Int) -> Double {
            let winners = skinsWinners(for: round)
            guard !winners.isEmpty else { return 0 }
            return skinsPot(for: round) / Double(winners.count)
        }

        // MARK: - 🤜🤛 Challenges & Trash Talk
        
        func issueChallenge(_ challenge: Challenge) async {
            do {
                try db.collection("challenges").document(challenge.id ?? UUID().uuidString).setData(from: challenge)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } catch {
                print("❌ Failed to issue challenge: \(error.localizedDescription)")
            }
        }

        func respondToChallenge(id: UUID, accept: Bool) async {
            let newStatus = accept ? ChallengeStatus.active.rawValue : ChallengeStatus.declined.rawValue
            try? await db.collection("challenges").document(id.uuidString).updateData([
                "status": newStatus,
                "strokesAccepted": accept ? FieldValue.increment(Int64(0)) : 0 // Retain offered strokes
            ])
        }

        func counterStrokeOffer(id: UUID, strokes: Int) async {
            try? await db.collection("challenges").document(id.uuidString).updateData([
                "status": ChallengeStatus.strokesCountered.rawValue,
                "strokesCountered": strokes
            ])
        }

        func respondToStrokeCounter(id: UUID, accept: Bool) async {
            let newStatus = accept ? ChallengeStatus.active.rawValue : ChallengeStatus.declined.rawValue
            try? await db.collection("challenges").document(id.uuidString).updateData([
                "status": newStatus,
                // If accepted, the countered amount becomes the accepted amount
                "strokesAccepted": accept ? FieldValue.increment(Int64(0)) : 0
            ])
        }

        func suggestedStrokes(challengerId: UUID, challengedId: UUID) -> Int {
            guard let challenger = players.first(where: { $0.id == challengerId }),
                  let challenged = players.first(where: { $0.id == challengedId }) else { return 0 }
            
            let diff = challenger.handicap - challenged.handicap
            // If challenger is worse (higher handicap), they get strokes.
            // If they are better, they give strokes. We return the absolute value for the UI to handle.
            return abs(diff)
        }
}
