//
//  LiveFeedViews.swift
//  The Rug
//
//  Live Activity Feed — Zone 3 on the Home screen.
//  Auto-populates from Firestore whenever a player scores birdie or better,
//  makes a deuce, or attests a completed scorecard.
//

import SwiftUI

// MARK: - Live Feed Section (drop into HomeView)

struct LiveFeedSection: View {
    @Environment(TournamentManager.self) private var manager

    // Only show the 20 most recent events, newest first
    var visibleEvents: [FeedEvent] {
        manager.feedEvents
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(20)
            .map { $0 }
    }

    // Collapse the whole section when the tournament hasn't started yet
    var isActive: Bool {
        manager.activeRound > 0
    }

    var body: some View {
        if isActive {
            VStack(spacing: 0) {

                // ── Section Header ────────────────────────────────────────
                HStack(spacing: 8) {
                    // Pulsing live dot
                    LivePulse()

                    Text("ON THE COURSE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(5)
                        .foregroundStyle(Color("DudeCupGreen"))

                    Spacer()

                    Text("\(visibleEvents.count)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 14)

                if visibleEvents.isEmpty {
                    // ── Empty State ───────────────────────────────────────
                    VStack(spacing: 10) {
                        Text("⛳️")
                            .font(.system(size: 40))
                        Text("QUIET ON THE COURSE")
                            .font(.system(size: 13, weight: .heavy))
                            .fontWidth(.compressed)
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.2))
                        Text("Big moments will appear here live.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)

                } else {
                    // ── Horizontal Card Scroll ────────────────────────────
                    // Shows 1.5 cards to hint scrollability
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(visibleEvents) { event in
                                FeedEventCard(event: event, manager: manager)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

// MARK: - Feed Event Card

struct FeedEventCard: View {
    let event: FeedEvent
    let manager: TournamentManager

    var config: FeedCardConfig { event.type.cardConfig }

    var playerName: String {
        // First name only — keeps cards compact
        event.playerName.components(separatedBy: " ").first ?? event.playerName
    }

    var timeAgo: String {
        let seconds = Int(-event.timestamp.timeIntervalSinceNow)
        if seconds < 60  { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    var holeContext: String? {
        guard let hole = event.holeNumber, let par = event.par else { return nil }
        return "R\(event.roundNumber) • HOLE \(hole) • PAR \(par)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top accent bar ─────────────────────────────────────────
            Rectangle()
                .fill(config.accentColor)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 10) {

                // Emoji + type label row
                HStack(spacing: 8) {
                    Text(config.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.label)
                            .font(.system(size: 13, weight: .black))
                            .fontWidth(.compressed)
                            .tracking(1)
                            .foregroundStyle(config.accentColor)

                        Text(timeAgo)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.25))
                    }

                    Spacer()
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Player name
                Text(playerName.uppercased())
                    .font(.system(size: 20, weight: .black))
                    .fontWidth(.compressed)
                    .tracking(1)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Hole context or round complete label
                if let context = holeContext {
                    Text(context)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.3))
                } else if event.type == .roundComplete, let score = event.score {
                    HStack(spacing: 4) {
                        Text("TOTAL")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(score)")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(config.accentColor)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 174)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(config.accentColor.opacity(0.2), lineWidth: 1)
        )
        // Subtle entrance animation
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Live Pulse Dot

struct LivePulse: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color("DudeCupGreen").opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(pulse ? 1.8 : 1.0)
                .opacity(pulse ? 0 : 1)

            Circle()
                .fill(Color("DudeCupGreen"))
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Feed Card Config

struct FeedCardConfig {
    let label: String
    let emoji: String
    let accentColor: Color
}

// MARK: - FeedEventType Extension

extension FeedEventType {
    var cardConfig: FeedCardConfig {
        switch self {
        case .holeInOne:
            return FeedCardConfig(
                label: "ACE",
                emoji: "⛳️",
                accentColor: Color(red: 1.0, green: 0.84, blue: 0.0) // gold
            )
        case .eagle:
            return FeedCardConfig(
                label: "EAGLE",
                emoji: "🦅",
                accentColor: Color(red: 0.3, green: 0.7, blue: 1.0) // blue
            )
        case .birdie:
            return FeedCardConfig(
                label: "BIRDIE",
                emoji: "🐦",
                accentColor: Color("DudeCupGreen")
            )
        case .deuce:
            return FeedCardConfig(
                label: "DEUCE",
                emoji: "2️⃣",
                accentColor: Color(red: 1.0, green: 0.85, blue: 0.3) // yellow
            )
        case .roundComplete:
            return FeedCardConfig(
                label: "CLUBHOUSE",
                emoji: "🏁",
                accentColor: Color.white.opacity(0.5)
            )
        }
    }
}
