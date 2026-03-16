//
//  MockData.swift
//  The Rug
//

import SwiftUI
import FirebaseFirestore
import Observation

// MARK: - Data Models

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let handicap: Int
    var team: String
    var avatarName: String
    var hometown: String
    var phone: String
    var email: String

    // Extended registration fields
    var nickname: String?
    var handicapIndex: Double?
    var ghinNumber: String?
    var photoURL: String?
    var venmoHandle: String?
    var aboutMe: String?
    var debutYear: Int?
    var tshirtSize: String?
    var registeredAt: Date?
    var isConfirmed: Bool = false

    // Computed helpers
    var displayName: String { nickname.map { "\"\($0)\"" } ?? name }
    var firstName: String { name.components(separatedBy: " ").first ?? name }
    var phoneCleaned: String { phone.filter { $0.isNumber } }
}

struct TournamentEvent: Identifiable, Codable {
    let id: UUID
    let title: String
    let location: String
    let startTime: Date
    let description: String
    let icon: String
    var isBonus: Bool = false
}

struct Course: Identifiable, Codable {
    let id: UUID
    let name: String
    let rating: Double
    let slope: Int
    let holes: [CourseHole]
    
    func strokeHoles(for handicapIndex: Int) -> [Int] {
        let strokesAllowed = min(36, max(0, handicapIndex))
        return holes.sorted { $0.strokeIndex < $1.strokeIndex }
            .prefix(strokesAllowed)
            .map { $0.number }
    }
    
    func stablefordPoints(hole holeNumber: Int, strokes: Int, handicapIndex: Int) -> Int {
        guard let hole = holes.first(where: { $0.number == holeNumber }) else { return 0 }
        let getsStroke = strokeHoles(for: handicapIndex).contains(holeNumber)
        let netStrokes = getsStroke ? strokes - 1 : strokes
        let diff = hole.par - netStrokes
        switch diff {
        case 2...: return 4
        case 1: return 3
        case 0: return 2
        case -1: return 1
        default: return 0
        }
    }
}

struct CourseHole: Codable {
    let number: Int
    let par: Int
    let strokeIndex: Int
    let yardage: Int
}

struct PastWinner: Identifiable, Codable {
    let id: UUID
    let year: String
    let winnerName: String
    let score: Int
}

struct Announcement: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let date: Date
    let author: String
}

// MARK: - Feed Event Model

enum FeedEventType: String, Codable, CaseIterable {
    case holeInOne     = "holeInOne"
    case eagle         = "eagle"
    case birdie        = "birdie"
    case deuce         = "deuce"
    case roundComplete = "roundComplete"
}

struct FeedEvent: Identifiable, Codable {
    let id: UUID
    let type: FeedEventType
    let playerId: UUID
    let playerName: String
    let roundNumber: Int
    let holeNumber: Int?
    let score: Int?
    let par: Int?
    let timestamp: Date

    init(id: UUID = UUID(), type: FeedEventType, playerId: UUID, playerName: String,
         roundNumber: Int, holeNumber: Int? = nil, score: Int? = nil, par: Int? = nil,
         timestamp: Date = Date()) {
        self.id = id; self.type = type; self.playerId = playerId; self.playerName = playerName
        self.roundNumber = roundNumber; self.holeNumber = holeNumber; self.score = score
        self.par = par; self.timestamp = timestamp
    }
}

// MARK: - Tee Sheet Models

struct TeeSheetGroup: Identifiable, Codable {
    let id: UUID
    var teeTime: Date
    var playerIds: [UUID]
    var isEmpty: Bool { playerIds.isEmpty }
}

struct TeeSheet: Identifiable, Codable {
    let id: UUID
    let roundNumber: Int
    var firstTeeTime: Date
    var intervalMinutes: Int
    var groups: [TeeSheetGroup]
    var isPublished: Bool

    mutating func recalculateTimes() {
        for i in groups.indices {
            groups[i].teeTime = firstTeeTime.addingTimeInterval(Double(i * intervalMinutes * 60))
        }
    }
}

// MARK: - Challenge Models

enum ChallengeType: String, Codable, CaseIterable {
    case lowRound    = "Low Round Score"
    case mostBirdies = "Most Birdies"
    case lowHole     = "Low Hole Score"
    case pickSix     = "Pick Six"

    var description: String {
        switch self {
        case .lowRound:    return "Lowest gross score in a round"
        case .mostBirdies: return "Most birdies in a round"
        case .lowHole:     return "Lowest score on a specific hole"
        case .pickSix:     return "Best combined score across 6 chosen holes"
        }
    }
    var icon: String {
        switch self {
        case .lowRound:    return "flag.checkered"
        case .mostBirdies: return "bird.fill"
        case .lowHole:     return "scope"
        case .pickSix:     return "list.number"
        }
    }
}

enum ChallengeStatus: String, Codable {
    case pending          = "pending"
    case active           = "active"
    case resolved         = "resolved"
    case declined         = "declined"
    case tied             = "tied"
    case strokesCountered = "strokesCountered"
}

struct Challenge: Identifiable, Codable {
    let id: UUID
    let challengerId: UUID
    let challengerName: String
    let challengedId: UUID
    let challengedName: String
    let type: ChallengeType
    let roundNumber: Int
    let holeNumber: Int?
    var selectedHoles: [Int] = []
    let amount: Double
    let trash: String?
    var strokesOffered: Int = 0
    var strokesCountered: Int?
    var strokesAccepted: Int = 0
    var status: ChallengeStatus
    var winnerId: UUID? = nil
    var winnerName: String? = nil
    let createdAt: Date
    var resolvedAt: Date? = nil
    var strokeSummary: String? = nil

    func loserId(currentPlayerId: UUID) -> UUID? {
        guard status == .resolved, let wid = winnerId else { return nil }
        if wid == challengerId { return challengedId }
        if wid == challengedId { return challengerId }
        return nil
    }
    func loserName() -> String? {
        guard status == .resolved, let wid = winnerId else { return nil }
        return wid == challengerId ? challengedName : challengerName
    }
    func involves(_ playerId: UUID) -> Bool {
        challengerId == playerId || challengedId == playerId
    }
}

// MARK: - Betting Models

enum BetType: String, Codable {
    case tournamentPurse = "Tournament Purse"
    case closestToPin    = "Closest to Pin"
    case random9         = "Random 9"
    case deuces          = "Deuces"
    case skins           = "Skins"
}

enum BetStatus: String, Codable {
    case notEntered    = "Not Entered"
    case entered       = "Entered"
    case paymentPending = "Payment Pending"
    case paid          = "Paid"
}

struct Bet: Identifiable, Codable {
    let id: UUID
    let type: BetType
    let amount: Double
    let description: String
    var isOpen: Bool
}

struct CTPContest: Identifiable, Codable {
    let id: UUID
    let round: Int
    let hole: Int
    let courseName: String
    var entries: [CTPEntry]
    var isClosed: Bool = false
    var winningEntryId: UUID? = nil
    var winnerEntry: CTPEntry? { entries.first { $0.id == winningEntryId } }
}

struct CTPEntry: Identifiable, Codable {
    let id: UUID
    let playerId: UUID
    let feet: Int
    let inches: Int
    var totalInches: Int { feet * 12 + inches }
    var displayDistance: String { "\(feet)' \(inches)\"" }
}

struct Random9Hole: Codable {
    let round: Int
    let hole: Int
}

struct Random9Selection: Codable {
    let holes: [Random9Hole]
    let generatedAt: Date
}

struct PlayerBetEntry: Identifiable, Codable {
    let id: UUID
    let playerId: UUID
    let betId: UUID
    var status: BetStatus
    var paidAt: Date?
}

// MARK: - Badge System

struct Badge: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let description: String
    let earnedAt: Date
}

// MARK: - DCPI Models

struct DCPIData {
    let currentDCPI: Double
    let officialHandicap: Int
    let trend: String
    let roundsUsed: Int
    let totalRounds: Int
    let yearlyDCPI: [(year: Int, dcpi: Double)]
}

// MARK: - Score Models

struct HoleScore: Codable {
    var strokes: Int
}

struct RoundScore: Identifiable, Codable {
    let id: UUID
    let roundNumber: Int
    let courseId: UUID
    var holes: [HoleScore]
    var isAttested: Bool = false

    var totalGross: Int { holes.reduce(0) { $0 + $1.strokes } }
    var isComplete: Bool { holes.count == 18 }
    var holesPlayed: Int { holes.count }
}

struct Score: Identifiable, Codable {
    let id: UUID
    let playerId: UUID
    var rounds: [RoundScore]

    var totalGross: Int { rounds.reduce(0) { $0 + $1.totalGross } }
    func netScore(handicap: Int) -> Int { totalGross - handicap }
    func grossForRound(_ roundNumber: Int) -> Int? {
        rounds.first(where: { $0.roundNumber == roundNumber })?.totalGross
    }
}

// MARK: - Tournament Data

struct TournamentData {
    static let shared = TournamentData()

    let players: [Player] = [
        Player(id: UUID(), name: "Andrew H.", handicap: 8, team: "Team Abide", avatarName: "crown.fill", hometown: "Chicago, IL", phone: "(508) 247-7146", email: "andrew@dudecup.com"),
        Player(id: UUID(), name: "Walter S.", handicap: 12, team: "Team Abide", avatarName: "person.fill", hometown: "Los Angeles, CA", phone: "(310) 555-0102", email: "walter@dudecup.com"),
        Player(id: UUID(), name: "Donny K.", handicap: 18, team: "Team Aggression", avatarName: "person.fill", hometown: "Portland, OR", phone: "(503) 555-0103", email: "donny@dudecup.com"),
        Player(id: UUID(), name: "The Jesus", handicap: 4, team: "Team Aggression", avatarName: "bolt.fill", hometown: "Miami, FL", phone: "(305) 555-0104", email: "jesus@dudecup.com"),
        Player(id: UUID(), name: "Maude L.", handicap: 22, team: "Team Abide", avatarName: "person.fill", hometown: "New York, NY", phone: "(212) 555-0105", email: "maude@dudecup.com"),
        Player(id: UUID(), name: "Jackie T.", handicap: 10, team: "Team Aggression", avatarName: "person.fill", hometown: "Dallas, TX", phone: "(214) 555-0106", email: "jackie@dudecup.com"),
        Player(id: UUID(), name: "Bunny L.", handicap: 28, team: "Team Abide", avatarName: "person.fill", hometown: "Minneapolis, MN", phone: "(612) 555-0107", email: "bunny@dudecup.com"),
        Player(id: UUID(), name: "Brandt", handicap: 15, team: "Team Aggression", avatarName: "person.fill", hometown: "Boston, MA", phone: "(617) 555-0108", email: "brandt@dudecup.com"),
        Player(id: UUID(), name: "Knox H.", handicap: 5, team: "Team Abide", avatarName: "person.fill", hometown: "Nashville, TN", phone: "(615) 555-0109", email: "knox@dudecup.com"),
        Player(id: UUID(), name: "Quintana", handicap: 0, team: "Team Aggression", avatarName: "star.fill", hometown: "San Antonio, TX", phone: "(210) 555-0110", email: "quintana@dudecup.com"),
        Player(id: UUID(), name: "Saddam", handicap: 14, team: "Team Abide", avatarName: "person.fill", hometown: "Detroit, MI", phone: "(313) 555-0111", email: "saddam@dudecup.com"),
        Player(id: UUID(), name: "Arthur D.", handicap: 20, team: "Team Aggression", avatarName: "person.fill", hometown: "Seattle, WA", phone: "(206) 555-0112", email: "arthur@dudecup.com"),
        Player(id: UUID(), name: "Marty", handicap: 16, team: "Team Abide", avatarName: "person.fill", hometown: "Denver, CO", phone: "(720) 555-0113", email: "marty@dudecup.com"),
        Player(id: UUID(), name: "Smokey", handicap: 9, team: "Team Aggression", avatarName: "flame.fill", hometown: "Atlanta, GA", phone: "(404) 555-0114", email: "smokey@dudecup.com"),
        Player(id: UUID(), name: "Gilbert", handicap: 25, team: "Team Abide", avatarName: "person.fill", hometown: "Phoenix, AZ", phone: "(602) 555-0115", email: "gilbert@dudecup.com"),
        Player(id: UUID(), name: "Woo", handicap: 11, team: "Team Aggression", avatarName: "person.fill", hometown: "San Francisco, CA", phone: "(415) 555-0116", email: "woo@dudecup.com"),
        Player(id: UUID(), name: "Treehorn", handicap: 7, team: "Team Abide", avatarName: "person.fill", hometown: "Las Vegas, NV", phone: "(702) 555-0117", email: "treehorn@dudecup.com"),
        Player(id: UUID(), name: "Duder", handicap: 13, team: "Team Aggression", avatarName: "person.fill", hometown: "Austin, TX", phone: "(512) 555-0118", email: "duder@dudecup.com"),
        Player(id: UUID(), name: "El Duderino", handicap: 19, team: "Team Abide", avatarName: "person.fill", hometown: "New Orleans, LA", phone: "(504) 555-0119", email: "elduderino@dudecup.com"),
        Player(id: UUID(), name: "Stranger", handicap: 6, team: "Team Aggression", avatarName: "mustache.fill", hometown: "Santa Fe, NM", phone: "(505) 555-0120", email: "stranger@dudecup.com"),
        Player(id: UUID(), name: "Gary", handicap: 17, team: "Team Abide", avatarName: "person.fill", hometown: "Kansas City, MO", phone: "(816) 555-0121", email: "gary@dudecup.com"),
        Player(id: UUID(), name: "Larry", handicap: 21, team: "Team Aggression", avatarName: "person.fill", hometown: "Philadelphia, PA", phone: "(215) 555-0122", email: "larry@dudecup.com"),
        Player(id: UUID(), name: "Francis", handicap: 3, team: "Team Abide", avatarName: "person.fill", hometown: "Charlotte, NC", phone: "(704) 555-0123", email: "francis@dudecup.com"),
        Player(id: UUID(), name: "Karl", handicap: 30, team: "Team Aggression", avatarName: "person.fill", hometown: "Milwaukee, WI", phone: "(414) 555-0124", email: "karl@dudecup.com")
    ]

    let itinerary: [TournamentEvent] = [
        TournamentEvent(id: UUID(), title: "Arrival & Draft Party", location: "Clubhouse Lounge", startTime: Date().addingTimeInterval(86400 * 1), description: "Check-in, grab your swag bag, and team drafts. White Russians served.", icon: "figure.socialdance"),
        TournamentEvent(id: UUID(), title: "Round 1: Scramble", location: "Desert Dunes Course", startTime: Date().addingTimeInterval(86400 * 2), description: "8:00 AM Shotgun Start. 4-man scramble format.", icon: "sun.max.fill"),
        TournamentEvent(id: UUID(), title: "The Gala Dinner", location: "Main Dining Hall", startTime: Date().addingTimeInterval((86400 * 2) + 28800), description: "Suit up. Steak dinner and day 1 awards.", icon: "wineglass.fill"),
        TournamentEvent(id: UUID(), title: "Round 2: Singles", location: "Mountain View Course", startTime: Date().addingTimeInterval(86400 * 3), description: "7:30 AM Tee times. Head-to-head matchups.", icon: "flag.fill")
    ]

    let history: [PastWinner] = [
        PastWinner(id: UUID(), year: "2025", winnerName: "Walter S.", score: -4),
        PastWinner(id: UUID(), year: "2024", winnerName: "Andrew H.", score: -2),
        PastWinner(id: UUID(), year: "2023", winnerName: "The Jesus", score: -5),
        PastWinner(id: UUID(), year: "2022", winnerName: "Donny K.", score: -1)
    ]

    let announcements: [Announcement] = [
        Announcement(id: UUID(), title: "Welcome to The Dude Cup 2026! 🏆", message: "Gentlemen, the time has come. Check the schedule, know your tee times, and may the best dude win.", date: Date(), author: "Drew Harris"),
        Announcement(id: UUID(), title: "Weather Advisory ⛅", message: "Slight chance of rain Saturday morning. Bring a layer. We're playing through it.", date: Date().addingTimeInterval(-3600), author: "Drew Harris"),
        Announcement(id: UUID(), title: "Dinner Reservation Confirmed 🥩", message: "Saturday night steakhouse is locked in for 7pm. Dress sharp. No cargo shorts, Walter.", date: Date().addingTimeInterval(-7200), author: "Drew Harris")
    ]

    let courses: [Course] = [
        Course(
            id: UUID(), name: "Ventana Canyon - Canyon", rating: 70.2, slope: 132,
            holes: [
                CourseHole(number: 1,  par: 4, strokeIndex: 8,  yardage: 398),
                CourseHole(number: 2,  par: 5, strokeIndex: 12, yardage: 472),
                CourseHole(number: 3,  par: 4, strokeIndex: 2,  yardage: 376),
                CourseHole(number: 4,  par: 4, strokeIndex: 18, yardage: 290),
                CourseHole(number: 5,  par: 3, strokeIndex: 16, yardage: 124),
                CourseHole(number: 6,  par: 4, strokeIndex: 6,  yardage: 386),
                CourseHole(number: 7,  par: 5, strokeIndex: 10, yardage: 526),
                CourseHole(number: 8,  par: 3, strokeIndex: 14, yardage: 156),
                CourseHole(number: 9,  par: 4, strokeIndex: 4,  yardage: 378),
                CourseHole(number: 10, par: 4, strokeIndex: 11, yardage: 314),
                CourseHole(number: 11, par: 4, strokeIndex: 3,  yardage: 423),
                CourseHole(number: 12, par: 5, strokeIndex: 9,  yardage: 535),
                CourseHole(number: 13, par: 3, strokeIndex: 15, yardage: 140),
                CourseHole(number: 14, par: 4, strokeIndex: 17, yardage: 276),
                CourseHole(number: 15, par: 4, strokeIndex: 1,  yardage: 452),
                CourseHole(number: 16, par: 3, strokeIndex: 13, yardage: 173),
                CourseHole(number: 17, par: 4, strokeIndex: 5,  yardage: 403),
                CourseHole(number: 18, par: 5, strokeIndex: 7,  yardage: 477)
            ]
        ),
        Course(
            id: UUID(), name: "Ventana Canyon - Mountain", rating: 70.2, slope: 136,
            holes: [
                CourseHole(number: 1,  par: 4, strokeIndex: 9,  yardage: 386),
                CourseHole(number: 2,  par: 4, strokeIndex: 3,  yardage: 336),
                CourseHole(number: 3,  par: 3, strokeIndex: 17, yardage: 104),
                CourseHole(number: 4,  par: 5, strokeIndex: 11, yardage: 512),
                CourseHole(number: 5,  par: 4, strokeIndex: 15, yardage: 361),
                CourseHole(number: 6,  par: 3, strokeIndex: 5,  yardage: 208),
                CourseHole(number: 7,  par: 4, strokeIndex: 1,  yardage: 416),
                CourseHole(number: 8,  par: 5, strokeIndex: 13, yardage: 474),
                CourseHole(number: 9,  par: 4, strokeIndex: 7,  yardage: 364),
                CourseHole(number: 10, par: 5, strokeIndex: 16, yardage: 521),
                CourseHole(number: 11, par: 4, strokeIndex: 12, yardage: 329),
                CourseHole(number: 12, par: 4, strokeIndex: 10, yardage: 382),
                CourseHole(number: 13, par: 4, strokeIndex: 8,  yardage: 361),
                CourseHole(number: 14, par: 3, strokeIndex: 14, yardage: 154),
                CourseHole(number: 15, par: 4, strokeIndex: 2,  yardage: 413),
                CourseHole(number: 16, par: 3, strokeIndex: 18, yardage: 139),
                CourseHole(number: 17, par: 4, strokeIndex: 4,  yardage: 374),
                CourseHole(number: 18, par: 5, strokeIndex: 6,  yardage: 564)
            ]
        )
    ]

    let bets: [Bet] = [
        Bet(id: UUID(uuidString: "BE700000-0000-0000-0000-000000000001")!, type: .tournamentPurse, amount: 100,
            description: "Main tournament entry fee. Payout based on final leaderboard position.", isOpen: true),
        Bet(id: UUID(uuidString: "BE700000-0000-0000-0000-000000000002")!, type: .closestToPin, amount: 80,
            description: "One entry ($80) gets you into all 8 CTP contests. Each contest pot = $10 × number of entries.", isOpen: true),
        Bet(id: UUID(uuidString: "BE700000-0000-0000-0000-000000000003")!, type: .random9, amount: 25,
            description: "Best gross score on 9 randomly selected holes across all 4 rounds.", isOpen: true),
        Bet(id: UUID(uuidString: "BE700000-0000-0000-0000-000000000004")!, type: .deuces, amount: 10,
            description: "Any player who scores a gross birdie (2) on ANY par 3 hole splits the pot equally.", isOpen: true),
        Bet(id: UUID(uuidString: "BE700000-0000-0000-0000-000000000005")!, type: .skins, amount: 20,
            description: "$20 per round. Each round's pot split equally among all entrants who score birdie or better.", isOpen: true)
    ]

    let ctpContests: [CTPContest] = [
        CTPContest(id: UUID(), round: 1, hole: 5,  courseName: "Canyon",   entries: []),
        CTPContest(id: UUID(), round: 1, hole: 13, courseName: "Canyon",   entries: []),
        CTPContest(id: UUID(), round: 2, hole: 3,  courseName: "Mountain", entries: []),
        CTPContest(id: UUID(), round: 2, hole: 16, courseName: "Mountain", entries: []),
        CTPContest(id: UUID(), round: 3, hole: 5,  courseName: "Canyon",   entries: []),
        CTPContest(id: UUID(), round: 3, hole: 13, courseName: "Canyon",   entries: []),
        CTPContest(id: UUID(), round: 4, hole: 3,  courseName: "Mountain", entries: []),
        CTPContest(id: UUID(), round: 4, hole: 16, courseName: "Mountain", entries: [])
    ]

    private func makeRound(roundNumber: Int, avgScore: Int, course: Course) -> RoundScore {
        let variance = [-2, -1, -1, 0, 0, 0, 1, 1, 2]
        let holes = (1...18).map { _ in
            HoleScore(strokes: max(1, (avgScore / 18) + (variance.randomElement() ?? 0)))
        }
        return RoundScore(id: UUID(), roundNumber: roundNumber, courseId: course.id, holes: holes)
    }

    var scores: [Score] {
        let canyon = courses[0]; let mountain = courses[1]
        let playerAverages: [(UUID, Int)] = zip(players, [
            78, 82, 88, 72, 92, 80, 96, 85, 75, 70,
            84, 90, 86, 79, 95, 81, 77, 83, 89, 76,
            87, 91, 73, 98
        ]).map { ($0.id, $1) }
        return playerAverages.map { (playerId, avg) in
            Score(id: UUID(), playerId: playerId, rounds: [
                makeRound(roundNumber: 1, avgScore: avg, course: canyon),
                makeRound(roundNumber: 2, avgScore: avg + Int.random(in: -2...2), course: mountain),
                makeRound(roundNumber: 3, avgScore: avg + Int.random(in: -2...2), course: canyon),
                makeRound(roundNumber: 4, avgScore: avg + Int.random(in: -2...2), course: mountain)
            ])
        }
    }
}

// MARK: - Tournament Manager

@Observable
class TournamentManager {
    var players: [Player]
    var courses: [Course]
    var scores: [Score]
    var schedule: [TournamentEvent]
    var announcements: [Announcement]
    var playerBadges: [UUID: String] = [:]
    var activeRound: Int = 1
    var isTournamentComplete: Bool = false
    var feedEvents: [FeedEvent] = []
    var teeSheets: [TeeSheet] = []

    static var shared = TournamentManager()

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    init() {
        self.players = TournamentData.shared.players
        self.courses = TournamentData.shared.courses
        self.scores  = TournamentData.shared.scores
        self.bets    = TournamentData.shared.bets
        self.ctpContests = TournamentData.shared.ctpContests
        self.betEntries = []
        self.random9Selection = nil
        self.schedule = TournamentData.shared.itinerary
        self.announcements = TournamentData.shared.announcements

        setupListeners()
        AuthManager.shared.retryPlayerLinkIfNeeded(players: self.players)

        #if DEBUG
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            if let andrew = self.players.first(where: { $0.name == "Andrew H." }) {
                DispatchQueue.main.async {
                    AuthManager.shared.currentPlayer = andrew
                    AuthManager.shared.isAuthenticated = true
                    print("🔧 DEBUG: Auto-logged in as \(andrew.name)")
                }
            }
        }
        #endif
    }

    // MARK: - Firestore Live Listeners

    func setupListeners() {
        // 1. Scores
        let scoresListener = db.collection("scores").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to scores: \(error)"); return }
            guard let documents = snapshot?.documents else { return }
            var loadedScores: [Score] = []
            for document in documents {
                let data = document.data()
                guard let playerIdString = data["playerId"] as? String,
                      let playerId = UUID(uuidString: playerIdString),
                      let roundsData = data["rounds"] as? [[String: Any]] else { continue }
                var rounds: [RoundScore] = []
                for roundData in roundsData {
                    guard let roundIdString = roundData["id"] as? String,
                          let roundId = UUID(uuidString: roundIdString),
                          let roundNumber = roundData["roundNumber"] as? Int,
                          let courseIdString = roundData["courseId"] as? String,
                          let courseId = UUID(uuidString: courseIdString),
                          let holesData = roundData["holes"] as? [[String: Any]] else { continue }
                    let holes = holesData.compactMap { holeData -> HoleScore? in
                        guard let strokes = holeData["strokes"] as? Int else { return nil }
                        return HoleScore(strokes: strokes)
                    }
                    let isAttested = roundData["isAttested"] as? Bool ?? false
                    rounds.append(RoundScore(id: roundId, roundNumber: roundNumber, courseId: courseId, holes: holes, isAttested: isAttested))
                }
                loadedScores.append(Score(id: UUID(uuidString: document.documentID) ?? UUID(), playerId: playerId, rounds: rounds))
            }
            Task { @MainActor in
                if !loadedScores.isEmpty { self.scores = loadedScores }
                self.calculatePlayerBadges()
                self.autoResolveChallenges()
                print("✅ Live updated \(loadedScores.count) scores from Firestore")
            }
        }
        listeners.append(scoresListener)
        
        // 5. Announcements
        let announcementsListener = db.collection("announcements").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Error listening to announcements: \(error)"); return }
            guard let documents = snapshot?.documents else { return }
            var loadedAnnouncements: [Announcement] = []
            for document in documents {
                let data = document.data()
                guard let title = data["title"] as? String, let message = data["message"] as? String,
                      let timestamp = data["date"] as? Timestamp, let author = data["author"] as? String else { continue }
                loadedAnnouncements.append(Announcement(id: UUID(uuidString: document.documentID) ?? UUID(),
                                                        title: title, message: message, date: timestamp.dateValue(), author: author))
            }
            Task { @MainActor in
                if !loadedAnnouncements.isEmpty { self.announcements = loadedAnnouncements; print("✅ Live updated \(loadedAnnouncements.count) announcements") }
            }
        }
        listeners.append(announcementsListener)
        
        // 6. Tournament State
        let stateListener = db.collection("tournament").document("state").addSnapshotListener { [weak self] document, error in
            guard let self = self else { return }
            if let data = document?.data() {
                Task { @MainActor in
                    self.activeRound = data["activeRound"] as? Int ?? 1
                    self.isTournamentComplete = data["isTournamentComplete"] as? Bool ?? false
                    print("✅ Live updated Tournament State: Round \(self.activeRound), Complete: \(self.isTournamentComplete)")
                }
            }
        }
        listeners.append(stateListener)
        
        // 7. Feed Events
        let feedListener = db.collection("feedEvents")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { print("❌ Feed listener error: \(error)"); return }
                guard let documents = snapshot?.documents else { return }
                var loaded: [FeedEvent] = []
                for doc in documents {
                    let data = doc.data()
                    guard let typeRaw = data["type"] as? String, let type = FeedEventType(rawValue: typeRaw),
                          let pidStr = data["playerId"] as? String, let pid = UUID(uuidString: pidStr),
                          let name = data["playerName"] as? String,
                          let round = data["roundNumber"] as? Int,
                          let tsRaw = data["timestamp"] as? Timestamp else { continue }
                    loaded.append(FeedEvent(id: UUID(uuidString: doc.documentID) ?? UUID(),
                                            type: type, playerId: pid, playerName: name, roundNumber: round,
                                            holeNumber: data["holeNumber"] as? Int, score: data["score"] as? Int,
                                            par: data["par"] as? Int, timestamp: tsRaw.dateValue()))
                }
                DispatchQueue.main.async { self.feedEvents = loaded }
            }
        listeners.append(feedListener)
        
        // 8. Tee Sheets
        let teeSheetListener = db.collection("teeSheets").addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error { print("❌ TeeSheet listener: \(error)"); return }
            guard let documents = snapshot?.documents else { return }
            var loaded: [TeeSheet] = []
            for doc in documents {
                let data = doc.data()
                guard let roundNumber = data["roundNumber"] as? Int,
                      let firstTsRaw = data["firstTeeTime"] as? Timestamp,
                      let intervalMins = data["intervalMinutes"] as? Int,
                      let isPublished = data["isPublished"] as? Bool,
                      let groupsRaw = data["groups"] as? [[String: Any]] else { continue }
                let groups: [TeeSheetGroup] = groupsRaw.compactMap { g in
                    guard let idStr = g["id"] as? String, let id = UUID(uuidString: idStr),
                          let ttRaw = g["teeTime"] as? Timestamp,
                          let pidStrs = g["playerIds"] as? [String] else { return nil }
                    return TeeSheetGroup(id: id, teeTime: ttRaw.dateValue(), playerIds: pidStrs.compactMap { UUID(uuidString: $0) })
                }.sorted { $0.teeTime < $1.teeTime }
                loaded.append(TeeSheet(id: UUID(uuidString: doc.documentID) ?? UUID(),
                                       roundNumber: roundNumber, firstTeeTime: firstTsRaw.dateValue(),
                                       intervalMinutes: intervalMins, groups: groups, isPublished: isPublished))
            }
            DispatchQueue.main.async { self.teeSheets = loaded }
        }
        listeners.append(teeSheetListener)
        
    }

    // MARK: - Round Management

    func openRound(_ roundNumber: Int) async {
        guard courses.count >= 2 else { print("❌ openRound: courses not loaded"); return }
        let courseForRound: Course = (roundNumber % 2 == 1) ? courses[0] : courses[1]
        let newRound = RoundScore(id: UUID(), roundNumber: roundNumber, courseId: courseForRound.id, holes: [])
        updateTournamentState(activeRound: roundNumber, isComplete: false)
        for player in players {
            if let existingIndex = scores.firstIndex(where: { $0.playerId == player.id }) {
                if !scores[existingIndex].rounds.contains(where: { $0.roundNumber == roundNumber }) {
                    scores[existingIndex].rounds.append(newRound)
                    await syncScoreToFirestore(scores[existingIndex])
                }
            } else {
                let score = Score(id: UUID(), playerId: player.id, rounds: [newRound])
                scores.append(score)
                await syncScoreToFirestore(score)
            }
        }
        print("✅ Opened Round \(roundNumber) on \(courseForRound.name) for \(players.count) players")
    }

    // MARK: - Scoring

    func stablefordTotal(score: Score, player: Player) -> Int {
        score.rounds.reduce(0) { total, round in
            guard let course = courses.first(where: { $0.id == round.courseId }) else { return total }
            return total + round.holes.enumerated().reduce(0) { roundTotal, pair in
                roundTotal + course.stablefordPoints(hole: pair.offset + 1, strokes: pair.element.strokes, handicapIndex: player.handicap)
            }
        }
    }

    func saveHoleScore(playerId: UUID, roundNumber: Int, holeIndex: Int, strokes: Int) {
        guard let scoreIndex = scores.firstIndex(where: { $0.playerId == playerId }) else { return }
        guard let roundIndex = scores[scoreIndex].rounds.firstIndex(where: { $0.roundNumber == roundNumber }) else { return }
        let round = scores[scoreIndex].rounds[roundIndex]
        if round.isAttested { return }
        let previousStrokes = holeIndex < round.holes.count ? round.holes[holeIndex].strokes : 0
        if holeIndex < round.holes.count {
            scores[scoreIndex].rounds[roundIndex].holes[holeIndex].strokes = strokes
        } else {
            scores[scoreIndex].rounds[roundIndex].holes.append(HoleScore(strokes: strokes))
        }
        let score = scores[scoreIndex]
        Task {
            await syncScoreToFirestore(score)
            guard strokes > 0, previousStrokes == 0 else { return }
            let holeNumber = holeIndex + 1
            guard let course = courses.first(where: { $0.id == round.courseId }),
                  let holeInfo = course.holes.first(where: { $0.number == holeNumber }),
                  let player = players.first(where: { $0.id == playerId }) else { return }
            let par = holeInfo.par
            let diff = strokes - par
            let eventType: FeedEventType? = {
                if strokes == 1 { return .holeInOne }
                if diff <= -2   { return .eagle }
                if diff == -1   { return .birdie }
                return nil
            }()
            if let type = eventType {
                await writeFeedEvent(FeedEvent(type: type, playerId: playerId, playerName: player.name,
                    roundNumber: roundNumber, holeNumber: holeNumber, score: strokes, par: par))
            }
            if par == 3 && strokes == 2 {
                await writeFeedEvent(FeedEvent(type: .deuce, playerId: playerId, playerName: player.name,
                    roundNumber: roundNumber, holeNumber: holeNumber, score: strokes, par: par))
            }
        }
    }

    func attestRound(playerId: UUID, roundNumber: Int) {
        guard let scoreIndex = scores.firstIndex(where: { $0.playerId == playerId }) else { return }
        guard let roundIndex = scores[scoreIndex].rounds.firstIndex(where: { $0.roundNumber == roundNumber }) else { return }
        scores[scoreIndex].rounds[roundIndex].isAttested = true
        let score = scores[scoreIndex]
        Task {
            await syncScoreToFirestore(score)
            guard let player = players.first(where: { $0.id == playerId }) else { return }
            let totalGross = scores[scoreIndex].rounds[roundIndex].totalGross
            await writeFeedEvent(FeedEvent(type: .roundComplete, playerId: playerId, playerName: player.name,
                roundNumber: roundNumber, score: totalGross))
        }
    }

    func unlockRound(playerId: UUID, roundNumber: Int) {
        guard let scoreIndex = scores.firstIndex(where: { $0.playerId == playerId }) else { return }
        guard let roundIndex = scores[scoreIndex].rounds.firstIndex(where: { $0.roundNumber == roundNumber }) else { return }
        scores[scoreIndex].rounds[roundIndex].isAttested = false
        let score = scores[scoreIndex]
        Task { await syncScoreToFirestore(score) }
    }

    func syncScoreToFirestore(_ score: Score) async {
        do {
            try await db.collection("scores").document(score.id.uuidString).setData([
                "playerId": score.playerId.uuidString,
                "rounds": score.rounds.map { round in [
                    "id": round.id.uuidString, "roundNumber": round.roundNumber,
                    "courseId": round.courseId.uuidString, "isAttested": round.isAttested,
                    "holes": round.holes.map { ["strokes": $0.strokes] }
                ]}
            ])
            print("✅ Synced score to Firestore for player \(score.playerId)")
        } catch { print("❌ Firestore sync error: \(error)") }
    }

    // MARK: - Feed Event Writer

    func writeFeedEvent(_ event: FeedEvent) async {
        var data: [String: Any] = [
            "type": event.type.rawValue, "playerId": event.playerId.uuidString,
            "playerName": event.playerName, "roundNumber": event.roundNumber,
            "timestamp": Timestamp(date: event.timestamp)
        ]
        if let h = event.holeNumber { data["holeNumber"] = h }
        if let s = event.score      { data["score"]      = s }
        if let p = event.par        { data["par"]        = p }
        do {
            try await db.collection("feedEvents").document(event.id.uuidString).setData(data)
            print("✅ Feed event written: \(event.type.rawValue) — \(event.playerName)")
        } catch { print("❌ Feed event write error: \(error)") }
    }

    func seedTestFeed() async {
        let cast: [(id: UUID, name: String)] = players.prefix(8).map { ($0.id, $0.name) }
        guard cast.count >= 4 else { print("⚠️ seedTestFeed: not enough players"); return }
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let events: [FeedEvent] = [
            FeedEvent(type: .holeInOne,     playerId: cast[0].id, playerName: cast[0].name, roundNumber: 1, holeNumber: 8,  score: 1, par: 3, timestamp: ago(3)),
            FeedEvent(type: .eagle,         playerId: cast[1].id, playerName: cast[1].name, roundNumber: 1, holeNumber: 5,  score: 3, par: 5, timestamp: ago(7)),
            FeedEvent(type: .deuce,         playerId: cast[2].id, playerName: cast[2].name, roundNumber: 1, holeNumber: 13, score: 2, par: 3, timestamp: ago(11)),
            FeedEvent(type: .birdie,        playerId: cast[3].id, playerName: cast[3].name, roundNumber: 1, holeNumber: 2,  score: 4, par: 5, timestamp: ago(14)),
            FeedEvent(type: .birdie,        playerId: cast[0].id, playerName: cast[0].name, roundNumber: 1, holeNumber: 3,  score: 3, par: 4, timestamp: ago(18)),
            FeedEvent(type: .roundComplete, playerId: cast[1].id, playerName: cast[1].name, roundNumber: 1, score: 74,                        timestamp: ago(22)),
            FeedEvent(type: .birdie,        playerId: cast[2].id, playerName: cast[2].name, roundNumber: 1, holeNumber: 7,  score: 2, par: 3, timestamp: ago(25)),
        ]
        await withTaskGroup(of: Void.self) { group in
            for event in events { group.addTask { await self.writeFeedEvent(event) } }
        }
        print("✅ Seeded \(events.count) test feed events")
    }

    // MARK: - Tee Sheet Helpers

    func teeSheet(for roundNumber: Int) -> TeeSheet? {
        teeSheets.first { $0.roundNumber == roundNumber }
    }

    func myGroup(playerId: UUID, roundNumber: Int) -> TeeSheetGroup? {
        teeSheet(for: roundNumber)?.groups.first { $0.playerIds.contains(playerId) }
    }

    func myTeeTime(playerId: UUID, roundNumber: Int) -> Date? {
        myGroup(playerId: playerId, roundNumber: roundNumber)?.teeTime
    }

    func unassignedPlayers(for sheet: TeeSheet) -> [Player] {
        let assigned = Set(sheet.groups.flatMap { $0.playerIds })
        return players.filter { !assigned.contains($0.id) }.sorted { $0.name < $1.name }
    }

    // MARK: - Tee Sheet Write Operations

    func saveTeeSheet(_ sheet: TeeSheet) async {
        let groupData: [[String: Any]] = sheet.groups.map { g in [
            "id": g.id.uuidString, "teeTime": Timestamp(date: g.teeTime),
            "playerIds": g.playerIds.map { $0.uuidString }
        ]}
        let data: [String: Any] = [
            "roundNumber": sheet.roundNumber, "firstTeeTime": Timestamp(date: sheet.firstTeeTime),
            "intervalMinutes": sheet.intervalMinutes, "isPublished": sheet.isPublished, "groups": groupData
        ]
        do {
            try await db.collection("teeSheets").document(sheet.id.uuidString).setData(data)
            print("✅ Tee sheet saved — Round \(sheet.roundNumber)")
        } catch { print("❌ Tee sheet save error: \(error)") }
    }

    func publishTeeSheet(roundNumber: Int) async {
        guard var sheet = teeSheet(for: roundNumber) else { return }
        sheet.isPublished = true
        if let i = teeSheets.firstIndex(where: { $0.roundNumber == roundNumber }) { teeSheets[i].isPublished = true }
        await saveTeeSheet(sheet)
        pushAnnouncement(title: "⛳️ Round \(roundNumber) Tee Times Are Live!",
                         message: "Check the Schedule tab for your group and tee time.", author: "The Commish")
    }

    func autoGeneratePairings(roundNumber: Int, firstTeeTime: Date, intervalMinutes: Int) -> TeeSheet {
        let sorted = players.sorted { $0.handicap > $1.handicap }
        let groupCount = Int(ceil(Double(sorted.count) / 4.0))
        var groups: [TeeSheetGroup] = (0..<groupCount).map { i in
            TeeSheetGroup(id: UUID(), teeTime: firstTeeTime.addingTimeInterval(Double(i * intervalMinutes * 60)), playerIds: [])
        }
        for (idx, player) in sorted.enumerated() {
            let row = idx / groupCount; let col = idx % groupCount
            let groupIdx = row % 2 == 0 ? col : (groupCount - 1 - col)
            if groups[groupIdx].playerIds.count < 4 { groups[groupIdx].playerIds.append(player.id) }
        }
        return TeeSheet(id: teeSheet(for: roundNumber)?.id ?? UUID(), roundNumber: roundNumber,
                        firstTeeTime: firstTeeTime, intervalMinutes: intervalMinutes, groups: groups, isPublished: false)
    }

    // MARK: - Skins Calculations

    var skinsEntrants: [Player] {
    func isEnteredSkins(playerId: UUID, round: Int) -> Bool {
        guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return false }
        return betEntries.contains { $0.betId == skinsBet.id && $0.playerId == playerId && $0.status == .paid }
    }

    func enterSkins(playerId: UUID, round: Int) {
        guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return }
        guard !betEntries.contains(where: { $0.betId == skinsBet.id && $0.playerId == playerId }) else { return }
        let entry = PlayerBetEntry(id: UUID(), playerId: playerId, betId: skinsBet.id, status: .paid, paidAt: Date())
        betEntries.append(entry)
        // TODO: persist to Firestore
    }

        guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return [] }
        let paidIds = Set(betEntries.filter { $0.betId == skinsBet.id && $0.status == .paid }.map { $0.playerId })
        return players.filter { paidIds.contains($0.id) }
    }

    func skinsPot(for round: Int) -> Double {
        guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return 0 }
        return skinsBet.amount * Double(skinsEntrants.count)
    }

    func skinsWinners(for roundNumber: Int) -> [Player] {
        skinsEntrants.filter { player in
            guard let score = scores.first(where: { $0.playerId == player.id }),
                  let round = score.rounds.first(where: { $0.roundNumber == roundNumber }),
                  round.isAttested,
                  let course = courses.first(where: { $0.id == round.courseId }) else { return false }
            return round.holes.enumerated().contains { (idx, hole) in
                guard hole.strokes > 0 else { return false }
                let holeNum = idx + 1
                guard let holeInfo = course.holes.first(where: { $0.number == holeNum }) else { return false }
                return hole.strokes < holeInfo.par
            }
        }
    }

    func skinsPayoutPerWinner(for roundNumber: Int) -> Double {
        let winners = skinsWinners(for: roundNumber)
        guard !winners.isEmpty else { return 0 }
        return skinsPot(for: roundNumber) / Double(winners.count)
    }

    func skinsEntrants(for round: Int) -> [Player] {
        guard let skinsBet = bets.first(where: { $0.type == .skins }) else { return [] }
        let paidIds = Set(betEntries.filter { $0.betId == skinsBet.id && $0.status == .paid }.map { $0.playerId })
        return players.filter { paidIds.contains($0.id) }
    }

    func suggestedStrokes(challengerId: UUID, challengedId: UUID) -> Int {
        let cHcp = players.first(where: { $0.id == challengerId })?.handicap ?? 0
        let dHcp = players.first(where: { $0.id == challengedId })?.handicap ?? 0
        return max(0, dHcp - cHcp)
    }

    func counterStrokeOffer(id: UUID, strokes: Int) async {
        guard let idx = challenges.firstIndex(where: { $0.id == id }) else { return }
        await MainActor.run {
            challenges[idx].strokesCountered = strokes
            challenges[idx].status = .strokesCountered
        }
        // TODO: persist to Firestore
    }

    func respondToStrokeCounter(id: UUID, accept: Bool) async {
        guard let idx = challenges.firstIndex(where: { $0.id == id }) else { return }
        await MainActor.run {
            if accept {
                challenges[idx].status = .active
            } else {
                challenges[idx].status = .declined
            }
        }
        // TODO: persist to Firestore
    }

    func enterBet(playerId: UUID, betId: UUID) {
        let entry = PlayerBetEntry(id: UUID(), playerId: playerId, betId: betId, status: .entered)
        betEntries.append(entry)
        Task {
            do {
                try await db.collection("betEntries").document(entry.id.uuidString).setData([
                    "id": entry.id.uuidString, "playerId": entry.playerId.uuidString,
                    "betId": entry.betId.uuidString, "status": entry.status.rawValue
                ])
                print("✅ Bet entry saved")
            } catch { print("❌ Bet entry error: \(error)") }
        }
    }

    // MARK: - DCPI Calculation

    func calculateDCPI(for playerId: UUID) -> DCPIData? {
        guard let player = players.first(where: { $0.id == playerId }) else { return nil }
        var allRounds: [(score: Int, rating: Double, slope: Int, date: Date, year: Int)] = []
        if let score = scores.first(where: { $0.playerId == playerId }) {
            for round in score.rounds where round.isComplete {
                guard let course = courses.first(where: { $0.id == round.courseId }) else { continue }
                allRounds.append((score: round.totalGross, rating: course.rating, slope: course.slope, date: Date(), year: 2026))
            }
        }
        guard !allRounds.isEmpty else { return nil }
        var differentials: [(diff: Double, year: Int)] = allRounds.map { round in
            ((Double(round.score) - round.rating) * (113.0 / Double(round.slope)), round.year)
        }
        differentials.sort { $0.diff < $1.diff }
        let totalRounds = differentials.count
        let roundsToUse = max(2, min(8, totalRounds / 2))
        let bestDifferentials = Array(differentials.prefix(roundsToUse))
        let averageDifferential = bestDifferentials.reduce(0.0) { $0 + $1.diff } / Double(bestDifferentials.count)
        let dcpi = averageDifferential * 0.96
        var yearlyDCPI: [(year: Int, dcpi: Double)] = []
        let groupedByYear = Dictionary(grouping: differentials, by: { $0.year })
        for (year, yearDiffs) in groupedByYear.sorted(by: { $0.key < $1.key }) {
            let yearRoundsToUse = max(2, min(8, yearDiffs.count / 2))
            let yearBest = Array(yearDiffs.sorted { $0.diff < $1.diff }.prefix(yearRoundsToUse))
            let yearAvg = yearBest.reduce(0.0) { $0 + $1.diff } / Double(yearBest.count)
            yearlyDCPI.append((year, yearAvg * 0.96))
        }
        let trend: String
        if yearlyDCPI.count >= 2 {
            let recent = yearlyDCPI.suffix(2)
            let change = recent.last!.dcpi - recent.first!.dcpi
            trend = change < -2.0 ? "Improving" : change > 2.0 ? "Declining" : "Steady"
        } else { trend = "New" }
        return DCPIData(currentDCPI: dcpi, officialHandicap: player.handicap, trend: trend,
                        roundsUsed: roundsToUse, totalRounds: totalRounds, yearlyDCPI: yearlyDCPI)
    }

    // MARK: - CTP Methods

    @MainActor
    func submitCTPEntry(contestId: UUID, playerId: UUID, feet: Int, inches: Int) async {
        let entry = CTPEntry(id: UUID(), playerId: playerId, feet: feet, inches: inches)
        if let contestIndex = ctpContests.firstIndex(where: { $0.id == contestId }) {
            ctpContests[contestIndex].entries.append(entry)
            await saveCTPContestToFirestore(ctpContests[contestIndex])
        }
    }

    func saveCTPContestToFirestore(_ contest: CTPContest) async {
        do {
            let entriesData = contest.entries.map { entry in [
                "id": entry.id.uuidString, "playerId": entry.playerId.uuidString,
                "feet": entry.feet, "inches": entry.inches
            ]}
            var data: [String: Any] = ["round": contest.round, "hole": contest.hole,
                "courseName": contest.courseName, "entries": entriesData, "isClosed": contest.isClosed]
            if let winnerId = contest.winningEntryId { data["winningEntryId"] = winnerId.uuidString }
            try await db.collection("ctpContests").document(contest.id.uuidString).setData(data)
            print("✅ CTP contest saved to Firestore")
        } catch { print("❌ Error saving CTP contest: \(error)") }
    }

    func adjudicateCTP(contestId: UUID, winningEntryId: UUID?) {
        guard let index = ctpContests.firstIndex(where: { $0.id == contestId }) else { return }
        ctpContests[index].isClosed = (winningEntryId != nil)
        ctpContests[index].winningEntryId = winningEntryId
        let contest = ctpContests[index]
        Task { await saveCTPContestToFirestore(contest) }
    }

    // MARK: - Random 9 Methods

    func generateRandom9() {
        var allHoles: [(round: Int, hole: Int)] = []
        for round in 1...4 { for hole in 1...18 { allHoles.append((round: round, hole: hole)) } }
        let selected = Array(allHoles.shuffled().prefix(9))
        random9Selection = Random9Selection(holes: selected.map { Random9Hole(round: $0.round, hole: $0.hole) }, generatedAt: Date())
        Task { await saveRandom9ToFirestore() }
    }

    func saveRandom9ToFirestore() async {
        guard let selection = random9Selection else { return }
        do {
            try await db.collection("random9").document("current").setData([
                "holes": selection.holes.map { ["round": $0.round, "hole": $0.hole] },
                "generatedAt": Timestamp(date: selection.generatedAt)
            ])
            print("✅ Random 9 saved to Firestore")
        } catch { print("❌ Error saving Random 9: \(error)") }
    }

    func random9Score(for playerId: UUID) -> Int? {
        guard let selection = random9Selection,
              let playerScore = scores.first(where: { $0.playerId == playerId }) else { return nil }
        var totalGross = 0; var holesScored = 0
        for r9Hole in selection.holes {
            if let round = playerScore.rounds.first(where: { $0.roundNumber == r9Hole.round }),
               r9Hole.hole <= round.holes.count {
                let holeScore = round.holes[r9Hole.hole - 1].strokes
                if holeScore > 0 { totalGross += holeScore; holesScored += 1 }
            }
        }
        return holesScored > 0 ? totalGross : nil
    }

    func isRandom9Hole(round: Int, hole: Int) -> Bool {
        guard let selection = random9Selection else { return false }
        return selection.holes.contains(where: { $0.round == round && $0.hole == hole })
    }

    // MARK: - The Banker (Betting)



    func toggleBetStatus(playerId: UUID, betId: UUID) {
        let existingEntryIndex = betEntries.firstIndex(where: { $0.playerId == playerId && $0.betId == betId })
        let entryToSave: PlayerBetEntry
        if let index = existingEntryIndex {
            let newStatus: BetStatus = betEntries[index].status == .paid ? .notEntered : .paid
            betEntries[index].status = newStatus
            betEntries[index].paidAt = newStatus == .paid ? Date() : nil
            entryToSave = betEntries[index]
        } else {
            entryToSave = PlayerBetEntry(id: UUID(), playerId: playerId, betId: betId, status: .paid, paidAt: Date())
            betEntries.append(entryToSave)
        }
        Task {
            do {
                var data: [String: Any] = ["id": entryToSave.id.uuidString, "playerId": entryToSave.playerId.uuidString,
                    "betId": entryToSave.betId.uuidString, "status": entryToSave.status.rawValue]
                if let paidAt = entryToSave.paidAt { data["paidAt"] = Timestamp(date: paidAt) }
                try await db.collection("betEntries").document(entryToSave.id.uuidString).setData(data)
            } catch { print("❌ Error saving bet entry: \(error)") }
        }
    }

    func playerSubmitBets(playerId: UUID, betIds: [UUID]) async {
        for betId in betIds {
            if let existingEntry = betEntries.first(where: { $0.playerId == playerId && $0.betId == betId }) {
                do {
                    try await db.collection("betEntries").document(existingEntry.id.uuidString).updateData([
                        "status": BetStatus.paid.rawValue, "paidAt": Timestamp(date: Date())
                    ])
                } catch { print("❌ Error updating bet: \(error)") }
            } else {
                let entry = PlayerBetEntry(id: UUID(), playerId: playerId, betId: betId, status: .paid, paidAt: Date())
                do {
                    try await db.collection("betEntries").document(entry.id.uuidString).setData([
                        "id": entry.id.uuidString, "playerId": entry.playerId.uuidString,
                        "betId": entry.betId.uuidString, "status": entry.status.rawValue,
                        "paidAt": Timestamp(date: entry.paidAt ?? Date())
                    ])
                } catch { print("❌ Error saving new bet: \(error)") }
            }
        }
    }

    // MARK: - The Megaphone (Announcements)

    func pushAnnouncement(title: String, message: String, author: String) {
        let announcement = Announcement(id: UUID(), title: title, message: message, date: Date(), author: author)
        announcements.append(announcement)
        Task {
            do {
                try await db.collection("announcements").document(announcement.id.uuidString).setData([
                    "title": announcement.title, "message": announcement.message,
                    "date": Timestamp(date: announcement.date), "author": announcement.author
                ])
                print("✅ Announcement pushed")
            } catch { print("❌ Error pushing announcement: \(error)") }
        }
    }

    // MARK: - Master Switch (Tournament State)

    func updateTournamentState(activeRound: Int, isComplete: Bool) {
        self.activeRound = activeRound
        self.isTournamentComplete = isComplete
        Task {
            do {
                try await db.collection("tournament").document("state").setData([
                    "activeRound": activeRound, "isTournamentComplete": isComplete
                ])
                print("✅ Tournament State updated")
            } catch { print("❌ Error updating tournament state: \(error)") }
        }
    }

    // MARK: - Badge Caching

    func calculatePlayerBadges() {
        var badgeCache: [UUID: String] = [:]
        for player in players {
            guard let score = scores.first(where: { $0.playerId == player.id }) else { continue }
            var hasEagle = false
            for round in score.rounds {
                guard let course = courses.first(where: { $0.id == round.courseId }) else { continue }
                for (index, hole) in round.holes.enumerated() {
                    if index < course.holes.count && hole.strokes > 0 && hole.strokes <= course.holes[index].par - 2 {
                        badgeCache[player.id] = "🦅"; hasEagle = true; break
                    }
                }
                if hasEagle { break }
            }
            if hasEagle { continue }
            var hasSnowman = false
            for round in score.rounds {
                if round.holes.contains(where: { $0.strokes == 8 }) { badgeCache[player.id] = "⛄"; hasSnowman = true; break }
            }
            if hasSnowman { continue }
            if betEntries.filter({ $0.playerId == player.id && $0.status == .paid }).count == 4 { badgeCache[player.id] = "🎰" }
        }
        self.playerBadges = badgeCache
    }

    // MARK: - Challenges

    func setupChallengesListener() {
        let listener = db.collection("challenges").addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error { print("❌ Challenges listener: \(error)"); return }
            guard let documents = snapshot?.documents else { return }
            var loaded: [Challenge] = []
            for doc in documents {
                let d = doc.data()
                guard let cidStr  = d["challengerId"]   as? String, let cid     = UUID(uuidString: cidStr),
                      let cname   = d["challengerName"] as? String,
                      let didStr  = d["challengedId"]   as? String, let did     = UUID(uuidString: didStr),
                      let dname   = d["challengedName"] as? String,
                      let typeRaw = d["type"]           as? String, let type    = ChallengeType(rawValue: typeRaw),
                      let round   = d["roundNumber"]    as? Int,
                      let amount  = d["amount"]         as? Double,
                      let statRaw = d["status"]         as? String, let status  = ChallengeStatus(rawValue: statRaw),
                      let tsRaw   = d["createdAt"]      as? Timestamp else { continue }
                loaded.append(Challenge(
                    id: UUID(uuidString: doc.documentID) ?? UUID(),
                    challengerId: cid, challengerName: cname, challengedId: did, challengedName: dname,
                    type: type, roundNumber: round, holeNumber: d["holeNumber"] as? Int,
                    selectedHoles: d["selectedHoles"] as? [Int] ?? [],
                    amount: amount, trash: d["trash"] as? String,
                    strokesOffered: d["strokesOffered"] as? Int ?? 0,
                    strokesCountered: d["strokesCountered"] as? Int,
                    strokesAccepted: d["strokesAccepted"] as? Int ?? 0,
                    status: status,
                    winnerId: (d["winnerId"] as? String).flatMap { UUID(uuidString: $0) },
                    winnerName: d["winnerName"] as? String,
                    createdAt: tsRaw.dateValue(),
                    resolvedAt: (d["resolvedAt"] as? Timestamp)?.dateValue()
                ))
            }
            DispatchQueue.main.async { self.challenges = loaded; self.autoResolveChallenges() }
        }
        listeners.append(listener)
    }

    func issueChallenge(_ challenge: Challenge) async {
        challenges.append(challenge)
        do {
            try await db.collection("challenges").document(challenge.id.uuidString).setData(challengeFirestoreData(challenge))
            print("✅ Challenge issued: \(challenge.challengerName) → \(challenge.challengedName)")
        } catch { print("❌ Challenge write error: \(error)") }
    }

    func respondToChallenge(id: UUID, accept: Bool) async {
        guard let idx = challenges.firstIndex(where: { $0.id == id }) else { return }
        challenges[idx].status = accept ? .active : .declined
        do {
            try await db.collection("challenges").document(id.uuidString).setData(challengeFirestoreData(challenges[idx]))
        } catch { print("❌ Challenge response error: \(error)") }
    }

    func autoResolveChallenges() {
        for (idx, challenge) in challenges.enumerated() {
            guard challenge.status == .active else { continue }
            guard let cRound = scores.first(where: { $0.playerId == challenge.challengerId })?.rounds.first(where: { $0.roundNumber == challenge.roundNumber }),
                  let dRound = scores.first(where: { $0.playerId == challenge.challengedId })?.rounds.first(where: { $0.roundNumber == challenge.roundNumber }),
                  cRound.isAttested, dRound.isAttested else { continue }
            let result = resolveResult(challenge: challenge, cRound: cRound, dRound: dRound)
            challenges[idx].status = result.status
            challenges[idx].winnerId = result.winnerId
            challenges[idx].winnerName = result.winnerName
            challenges[idx].resolvedAt = Date()
            let updated = challenges[idx]
            Task {
                try? await self.db.collection("challenges").document(updated.id.uuidString).setData(self.challengeFirestoreData(updated))
            }
        }
    }

    private func resolveResult(challenge: Challenge, cRound: RoundScore, dRound: RoundScore)
        -> (status: ChallengeStatus, winnerId: UUID?, winnerName: String?) {
        switch challenge.type {
        case .lowRound:
            let cG = cRound.totalGross, dG = dRound.totalGross
            if cG < dG { return (.resolved, challenge.challengerId, challenge.challengerName) }
            if dG < cG { return (.resolved, challenge.challengedId, challenge.challengedName) }
            return (.tied, nil, nil)
        case .mostBirdies:
            func birdieCount(_ round: RoundScore) -> Int {
                guard let course = courses.first(where: { $0.id == round.courseId }) else { return 0 }
                return round.holes.enumerated().filter { (idx, hole) in
                    guard hole.strokes > 0 else { return false }
                    guard let info = course.holes.first(where: { $0.number == idx + 1 }) else { return false }
                    return hole.strokes < info.par
                }.count
            }
            let cB = birdieCount(cRound), dB = birdieCount(dRound)
            if cB > dB { return (.resolved, challenge.challengerId, challenge.challengerName) }
            if dB > cB { return (.resolved, challenge.challengedId, challenge.challengedName) }
            return (.tied, nil, nil)
        case .lowHole:
            guard let holeNum = challenge.holeNumber else { return (.tied, nil, nil) }
            let holeIdx = holeNum - 1
            let cS = holeIdx < cRound.holes.count ? cRound.holes[holeIdx].strokes : 0
            let dS = holeIdx < dRound.holes.count ? dRound.holes[holeIdx].strokes : 0
            guard cS > 0, dS > 0 else { return (.tied, nil, nil) }
            if cS < dS { return (.resolved, challenge.challengerId, challenge.challengerName) }
            if dS < cS { return (.resolved, challenge.challengedId, challenge.challengedName) }
            return (.tied, nil, nil)
        case .pickSix:
            let holes = challenge.selectedHoles
            let cScore = holes.compactMap { h -> Int? in
                let idx = h - 1
                return idx < cRound.holes.count ? cRound.holes[idx].strokes : nil
            }.reduce(0, +)
            let dScore = holes.compactMap { h -> Int? in
                let idx = h - 1
                return idx < dRound.holes.count ? dRound.holes[idx].strokes : nil
            }.reduce(0, +)
            if cScore < dScore { return (.resolved, challenge.challengerId, challenge.challengerName) }
            if dScore < cScore { return (.resolved, challenge.challengedId, challenge.challengedName) }
            return (.tied, nil, nil)
        }
    }

    private func challengeFirestoreData(_ c: Challenge) -> [String: Any] {
        var data: [String: Any] = [
            "challengerId": c.challengerId.uuidString, "challengerName": c.challengerName,
            "challengedId": c.challengedId.uuidString, "challengedName": c.challengedName,
            "type": c.type.rawValue, "roundNumber": c.roundNumber, "amount": c.amount,
            "status": c.status.rawValue, "createdAt": Timestamp(date: c.createdAt)
        ]
        if let h = c.holeNumber  { data["holeNumber"]  = h }
        if let t = c.trash       { data["trash"]       = t }
        if let w = c.winnerId    { data["winnerId"]    = w.uuidString }
        if let wn = c.winnerName { data["winnerName"]  = wn }
        if let r = c.resolvedAt  { data["resolvedAt"]  = Timestamp(date: r) }
        return data
    }

    // MARK: - Nuclear Reset

    func resetAllData() async {
        print("🔴 Starting full Firebase reset...")
        let collections = ["scores", "ctpContests", "betEntries", "announcements", "feedEvents", "teeSheets", "challenges"]
        for col in collections {
            do {
                let snapshot = try await db.collection(col).getDocuments()
                for doc in snapshot.documents { try await db.collection(col).document(doc.documentID).delete() }
                print("✅ Cleared \(col) (\(snapshot.documents.count) docs)")
            } catch { print("❌ Failed to clear \(col): \(error)") }
        }
        do { try await db.collection("random9").document("current").delete() } catch { print("❌ Failed to clear random9") }
        do { try await db.collection("tournament").document("state").delete() } catch { print("❌ Failed to clear tournament/state") }
        await MainActor.run {
            self.scores = []; self.ctpContests = []; self.random9Selection = nil
            self.betEntries = []; self.announcements = []; self.activeRound = 1
            self.isTournamentComplete = false; self.playerBadges = [:]
            self.feedEvents = []; self.teeSheets = []; self.challenges = []
            print("✅ Local state reset complete")
        }
    }
}
