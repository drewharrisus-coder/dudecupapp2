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
            // Note: Betting badge logic will be restored when stores are fully connected
        }
        self.playerBadges = badgeCache
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
            self.scores = []
            self.announcements = []; self.activeRound = 1
            self.isTournamentComplete = false; self.playerBadges = [:]
            self.feedEvents = []; self.teeSheets = []
            print("✅ Local state reset complete")
        }
    }
}
