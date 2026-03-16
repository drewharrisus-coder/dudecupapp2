import Foundation
import FirebaseFirestore

// MARK: - Core Betting Models

struct Bet: Identifiable, Codable {
    @DocumentID var id: String?
    let amount: Double
    let type: BetType
    let description: String
}

struct PlayerBetEntry: Identifiable, Codable {
    @DocumentID var id: String?
    let playerId: String
    let betId: String
    let status: BetStatus
    let paidAt: Date?
}

// MARK: - CTP (Closest to Pin) Models

struct CTPContest: Identifiable, Codable {
    @DocumentID var id: String?
    let round: Int
    let hole: Int
    let courseName: String
    let entries: [CTPEntry]
    let isClosed: Bool
    let winningEntryId: String?
}

struct CTPEntry: Identifiable, Codable {
    let id: String
    let playerId: String
    let feet: Int
    let inches: Int
    
    var totalInches: Int { (feet * 12) + inches }
    var displayDistance: String { "\(feet)' \(inches)\"" }
}

// MARK: - Random 9 Models

struct Random9Selection: Codable {
    let holes: [Random9Hole]
    @ServerTimestamp var generatedAt: Date?
}

struct Random9Hole: Codable {
    let round: Int
    let hole: Int
}

// MARK: - Challenges Models

struct Challenge: Identifiable, Codable {
    @DocumentID var id: String?
    let challengerId: String
    let challengerName: String
    let challengedId: String
    let challengedName: String
    let type: ChallengeType
    let roundNumber: Int
    let holeNumber: Int?
    let selectedHoles: [Int]
    let amount: Double
    let trash: String?
    let strokesOffered: Int
    let strokesCountered: Int?
    let strokesAccepted: Int
    let status: ChallengeStatus
    @ServerTimestamp var createdAt: Date?
    var resolvedAt: Date?
    var winnerId: String?
    var winnerName: String?
}

// MARK: - Enums (Ensure these are backed by String for Codable)

enum BetType: String, Codable, CaseIterable {
    case tournamentPurse = "Tournament Purse"
    case closestToPin = "Closest to Pin"
    case random9 = "Random 9"
    case deuces = "Deuces"
    case skins = "Skins"
}

enum BetStatus: String, Codable {
    case notEntered, entered, paymentPending, paid
}

enum ChallengeType: String, Codable, CaseIterable {
    case lowRound = "Low Round"
    case lowHole = "Low Hole"
    case pickSix = "Pick 6"
    // Add other types mapped to your app...
}

enum ChallengeStatus: String, Codable {
    case pending, strokesCountered, active, resolved, declined, tied
}
