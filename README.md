# The Dude Cup - iOS App Architecture

## 📱 Overview

A clean, modern SwiftUI architecture for your annual golf tournament app, built for iOS 17+ with the new `@Observable` macro.

## 🏗️ Architecture Components

### 1. **Data Models** (`DudeCupModels.swift`)

#### `Player`
Represents a tournament participant with:
- Basic info (name, nickname, email, phone)
- Golf stats (handicap)
- Team assignment
- Photo support

#### `TournamentEvent`
Schedule entries with:
- Event type (arrival, practice, tournament, meal, social, awards, departure)
- Timing (day, start/end times)
- Location and description
- Built-in icons and colors per event type

#### `ScoreEntry`
Detailed scoring with:
- Hole-by-hole tracking (strokes, putts, fairways, GIR)
- Automatic gross/net calculations
- Front/back nine splits
- Round identification

#### `PastWinner`
Tournament history tracking:
- Winner and runner-up
- Scores and year
- Notes/highlights

### 2. **App State** (`TournamentManager`)

Single source of truth using the new `@Observable` macro (iOS 17+):
- Manages all players, schedule, scores, and history
- Provides convenience methods for CRUD operations
- Handles leaderboard calculations
- Supports JSON loading from bundle

**Key Methods:**
```swift
// Player Management
manager.addPlayer(player)
manager.getPlayer(byId: id)

// Schedule Management
manager.addEvent(event)
manager.getEvents(forDay: 1)

// Scoring
manager.addScore(scoreEntry)
manager.getLeaderboard(forRound: 1)
manager.getScores(forPlayer: playerId)
```

## 📦 Mock Data

### Players (`players.json`)
- 24 unique golfers with fun nicknames
- 12 teams of 2 players
- Realistic handicaps (5-16 range)
- Contact information

### Schedule (`schedule.json`)
- Full 3-day itinerary
- 15 events including:
  - Day 1: Arrival, practice round, welcome BBQ
  - Day 2: Round 1, meals, social events, poker night
  - Day 3: Championship round, awards, farewell
- Realistic timing with ISO 8601 dates

### Past Winners (`past_winners.json`)
- 6 years of tournament history (2019-2024)
- Winning scores and runner-ups
- Memorable notes from each year

## 🚀 Quick Start

### 1. Add Files to Your Xcode Project

```
YourApp/
├── Models/
│   └── DudeCupModels.swift
└── Resources/
    ├── players.json
    ├── schedule.json
    └── past_winners.json
```

### 2. Create Your App Entry Point

```swift
import SwiftUI

@main
struct DudeCupApp: App {
    @State private var tournamentManager = TournamentManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tournamentManager)
        }
    }
}
```

### 3. Use in Your Views

```swift
import SwiftUI

struct ContentView: View {
    @Environment(TournamentManager.self) private var manager
    
    var body: some View {
        TabView {
            PlayersListView()
                .tabItem { Label("Players", systemImage: "person.3.fill") }
            
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
            
            LeaderboardView()
                .tabItem { Label("Scores", systemImage: "list.number") }
            
            HistoryView()
                .tabItem { Label("History", systemImage: "trophy.fill") }
        }
    }
}
```

## 💡 Example Views

### Players List View

```swift
struct PlayersListView: View {
    @Environment(TournamentManager.self) private var manager
    @State private var searchText = ""
    
    var filteredPlayers: [Player] {
        if searchText.isEmpty {
            return manager.players
        }
        return manager.players.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nickname?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredPlayers) { player in
                    NavigationLink(value: player) {
                        PlayerRowView(player: player)
                    }
                }
            }
            .navigationTitle("The Dude Cup")
            .navigationDestination(for: Player.self) { player in
                PlayerDetailView(player: player)
            }
            .searchable(text: $searchText)
        }
    }
}

struct PlayerRowView: View {
    let player: Player
    
    var body: some View {
        HStack {
            // Profile image placeholder
            Circle()
                .fill(.blue.gradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(player.name.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.headline)
                
                HStack {
                    if let team = player.teamName {
                        Text(team)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("HCP: \(player.handicap)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
```

### Schedule View

```swift
struct ScheduleView: View {
    @Environment(TournamentManager.self) private var manager
    
    var groupedEvents: [Int: [TournamentEvent]] {
        Dictionary(grouping: manager.schedule) { $0.day }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedEvents.keys.sorted(), id: \.self) { day in
                    Section {
                        ForEach(groupedEvents[day] ?? []) { event in
                            EventRowView(event: event)
                        }
                    } header: {
                        Text("Day \(day)")
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Schedule")
        }
    }
}

struct EventRowView: View {
    let event: TournamentEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Event icon
            Image(systemName: event.eventType.icon)
                .font(.title2)
                .foregroundStyle(event.eventType.color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(event.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                
                Text(event.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if event.isRequired {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### Leaderboard View

```swift
struct LeaderboardView: View {
    @Environment(TournamentManager.self) private var manager
    @State private var selectedRound: Int?
    
    var leaderboard: [(player: Player, totalScore: Int, totalNet: Int)] {
        manager.getLeaderboard(forRound: selectedRound)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(leaderboard.enumerated()), id: \.element.player.id) { index, entry in
                    LeaderboardRowView(
                        position: index + 1,
                        player: entry.player,
                        score: entry.totalNet
                    )
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All Rounds") { selectedRound = nil }
                        Divider()
                        ForEach(1...2, id: \.self) { round in
                            Button("Round \(round)") { selectedRound = round }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

struct LeaderboardRowView: View {
    let position: Int
    let player: Player
    let score: Int
    
    var positionColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
    
    var body: some View {
        HStack {
            // Position
            ZStack {
                Circle()
                    .fill(positionColor.gradient)
                    .frame(width: 36, height: 36)
                
                Text("\(position)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(position <= 3 ? .white : .primary)
            }
            
            VStack(alignment: .leading) {
                Text(player.displayName)
                    .font(.headline)
                
                if let team = player.teamName {
                    Text(team)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(score)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
        }
    }
}
```

## 🎨 Customization Ideas

### Add App-wide Theme
```swift
struct DudeCupApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tournamentManager)
                .tint(.green) // Golf-themed accent color
        }
    }
}
```

### Custom Fonts
```swift
extension Font {
    static let dudeCupTitle = Font.custom("YourCustomFont-Bold", size: 28)
    static let dudeCupBody = Font.custom("YourCustomFont-Regular", size: 16)
}
```

### Live Scoring Updates
Integrate with CloudKit or Firebase to sync scores in real-time:
```swift
class TournamentManager {
    func syncWithCloud() async throws {
        // Implement CloudKit sync
    }
}
```

## 🛠️ Next Steps

1. **Add Photos**: Integrate PhotosPicker for player profile images
2. **Score Input**: Create a form for hole-by-hole scoring
3. **Stats Dashboard**: Visualize tournament stats with Charts framework
4. **Notifications**: Send push notifications for tee times
5. **Share Sheet**: Let players share leaderboard on social media
6. **Dark Mode**: Ensure all views support dark mode
7. **iPad Support**: Optimize layouts for larger screens

## 📱 iOS Requirements

- **Minimum**: iOS 17.0
- **Recommended**: iOS 17.4+
- **SwiftUI**: Latest features (`@Observable`, modern APIs)
- **Dependencies**: None (pure SwiftUI + Foundation)

## 🏌️ Tournament Tips

The app structure supports various tournament formats:
- **Stroke Play**: Individual net/gross scores
- **Match Play**: Add head-to-head matchups
- **Scramble**: Track team scores
- **Skins**: Track hole winners
- **Stableford**: Modify scoring system

Happy coding, and may the best dude win! ⛳️
