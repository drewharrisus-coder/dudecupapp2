//
//  ContentView.swift
//  The Rug
//

import SwiftUI
import Combine

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case feed, board, round, action, me
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var selectedTab: AppTab = .feed
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .feed:
                    NavigationStack { HomeView() }
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                case .board:
                    NavigationStack { LeaderboardView() }
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                case .round:
                    NavigationStack { MyRoundView() }
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                case .action:
                    NavigationStack { ActionView() }
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                case .me:
                    NavigationStack { MeView() }
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar floats over content
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let pillHeight: CGFloat = 64
    private let ballSize: CGFloat   = 78
    private let ballLift: CGFloat   = 0    // flush — sits right in the pill

    var body: some View {
        ZStack(alignment: .bottom) {
            // The pill
            HStack(spacing: 0) {
                tabButton(.feed,   icon: "waveform",         side: .left)
                tabButton(.board,  icon: "list.number",      side: .left)
                Spacer().frame(width: ballSize + 8)         // gap for ball
                tabButton(.action, icon: "bolt.fill",        side: .right)
                tabButton(.me,     icon: "person.fill",      side: .right)
            }
            .frame(height: pillHeight)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: pillHeight / 2)
                    .fill(Color(white: 0.1))
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: pillHeight / 2)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Golf ball center button — sits above pill
            GolfBallButton(isSelected: selectedTab == .round) {
                selectedTab = .round
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            .frame(width: ballSize, height: ballSize)
            .offset(y: -(pillHeight * 0.5 + ballLift + 24))  // 24 = bottom padding
        }
    }

    private enum Side { case left, right }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, icon: String, side: Side) -> some View {
        let isActive = selectedTab == tab
        Button {
            selectedTab = tab
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? Color("DudeCupGreen") : .white.opacity(0.35))
                    .scaleEffect(isActive ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)

                Circle()
                    .fill(Color("DudeCupGreen"))
                    .frame(width: 4, height: 4)
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Golf Ball Button

struct GolfBallButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Image overscaled so the ball face fills the circle edge-to-edge
                // clipShape on the ZStack (below) — NOT on the image — keeps ring and clip on same circle
                Image("DudeCupBall")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)

                // Rim sits tight on the same circle as the clip
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.90, green: 0.70, blue: 0.65).opacity(0.75),
                                Color(red: 0.65, green: 0.45, blue: 0.40).opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
            .frame(width: 78, height: 78)
            .clipShape(Circle())   // one clip — governs both image and rim
            .shadow(color: Color(red: 0.85, green: 0.60, blue: 0.55).opacity(isSelected ? 0.80 : 0.45),
                    radius: isSelected ? 24 : 16, y: 2)
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .contentShape(Circle().size(width: 78, height: 78))
    }
}

// MARK: - Action View (Betting + Skins + Challenges hub)

struct ActionView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager

    var me: Player? { authManager.currentPlayer }

    var activeChallenges: Int {
        guard let me else { return 0 }
        return manager.challenges.filter { $0.involves(me.id) && $0.status == .active }.count
    }
    var pendingChallenges: Int {
        guard let me else { return 0 }
        return manager.challenges.filter { $0.challengedId == me.id && $0.status == .pending }.count
    }
    var totalActionPot: Double {
        let betsPot = manager.bets.reduce(0.0) { sum, bet in
            sum + bet.amount * Double(manager.betEntries.filter { $0.betId == bet.id && $0.status == .paid }.count)
        }
        let challengesPot = manager.challenges
            .filter { $0.status == .active || $0.status == .pending }
            .reduce(0.0) { $0 + $1.amount * 2 } // both sides of each wager
        return betsPot + challengesPot
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    challengesCard
                    bettingCard
                    ledgerCard
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // ── Challenges card ───────────────────────────────────────────────────

    private let roseGold = Color(red: 0.82, green: 0.58, blue: 0.54)

    var challengesCard: some View {
        let totalDuels = activeChallenges + pendingChallenges

        return NavigationLink(destination: ChallengesView()) {
            HStack(spacing: 0) {

                // VS icon — left column
                Image("VersusIcon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .padding(.leading, 12)

                // Text — right side
                VStack(alignment: .leading, spacing: 6) {
                    Text("MATCHUPS")
                        .font(.system(size: 38, weight: .black)).fontWidth(.condensed)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(totalDuels) ACTIVE CHALLENGE\(totalDuels == 1 ? "" : "S")")
                        .font(.system(size: 12, weight: .heavy)).tracking(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(roseGold)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.trailing, 16)
            }
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(roseGold.opacity(0.20), lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.top, 16)
    }

    // ── Betting card ──────────────────────────────────────────────────────

    // Gold color to match Ben Franklin's money vibe
    private let benGold = Color(red: 0.82, green: 0.68, blue: 0.30)

    var bettingCard: some View {
        let myId = me?.id ?? UUID()
        let enteredCount = manager.bets.filter { b in
            if b.type == .skins {
                return (1...4).contains { manager.isEnteredSkins(playerId: myId, round: $0) }
            }
            return manager.betEntries.contains { $0.betId == b.id && $0.playerId == myId && $0.status == .paid }
        }.count
        let totalPot = manager.bets.reduce(0.0) { sum, bet in
            let paid = manager.betEntries.filter { $0.betId == bet.id && $0.status == .paid }
            return sum + bet.amount * Double(paid.count)
        }

        return NavigationLink(destination: BettingView()) {
            HStack(spacing: 0) {

                // Ben Franklin — left side, fixed width column
                Image("BenFranklinCig")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .padding(.leading, 12)

                // Text — right side
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROP BETS")
                        .font(.system(size: 38, weight: .black)).fontWidth(.condensed)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if totalPot > 0 {
                        Text("$\(Int(totalPot)) IN PLAY")
                            .font(.system(size: 12, weight: .heavy)).tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(benGold)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.trailing, 16)
            }
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(benGold.opacity(0.20), lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.top, 10)
    }

    // ── Ledger card ───────────────────────────────────────────────────────

    private let ledgerGreen = Color(red: 0.25, green: 0.75, blue: 0.45)
    private let ledgerRed   = Color(red: 0.85, green: 0.30, blue: 0.30)

    var ledgerCard: some View {
        let upCount   = manager.players.filter { p in
            let net = playerNet(p.id)
            return net > 0
        }.count
        let downCount = manager.players.filter { p in
            let net = playerNet(p.id)
            return net < 0
        }.count

        return NavigationLink(destination: LedgerView()) {
            HStack(spacing: 0) {
                // Volatility image — left column matching other cards
                Image("Volatility")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .padding(.leading, 12)

                // Text — right side
                VStack(alignment: .leading, spacing: 6) {
                    Text("THE LEDGER")
                        .font(.system(size: 38, weight: .black)).fontWidth(.condensed)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Pill matching other cards, split green/red
                    HStack(spacing: 0) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(ledgerGreen)
                            Text("\(upCount) UP")
                                .font(.system(size: 12, weight: .heavy)).tracking(1)
                                .foregroundStyle(ledgerGreen)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(ledgerGreen.opacity(0.15))

                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(ledgerRed)
                            Text("\(downCount) DOWN")
                                .font(.system(size: 12, weight: .heavy)).tracking(1)
                                .foregroundStyle(ledgerRed)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(ledgerRed.opacity(0.15))
                    }
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.trailing, 16)
            }
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.top, 10)
    }

    func playerNet(_ playerId: UUID) -> Double {
        let betAmountIn = manager.betEntries
            .filter { $0.playerId == playerId && $0.status == .paid }
            .reduce(0.0) { sum, entry in
                sum + (manager.bets.first(where: { $0.id == entry.betId })?.amount ?? 0)
            }
        let skinsBet = manager.bets.first(where: { $0.type == .skins })
        let skinsIn = skinsBet.map { b in
            Double((1...4).filter { manager.isEnteredSkins(playerId: playerId, round: $0) }.count) * b.amount
        } ?? 0
        let totalIn = betAmountIn + skinsIn
        let won = manager.challenges
            .filter { $0.status == .resolved && $0.winnerId == playerId }
            .reduce(0.0) { $0 + $1.amount * 2 }
        return won - totalIn
    }

    // ── Shared card builder ───────────────────────────────────────────────

    func actionCard(icon: String, color: Color, title: String, subtitle: String,
                    subtitleColor: Color, badge: String?, badgeColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .black)).fontWidth(.compressed)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .heavy)).tracking(2)
                    .foregroundStyle(subtitleColor)
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(badgeColor)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(20)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Me View (personal hub)

struct MeView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager
    @State private var showPlayers = false

    var me: Player? { authManager.currentPlayer }
    var isCommish: Bool { me?.name == "Andrew H." }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    meHeader
                    menuLinks
                    if isCommish { commishLink }
                    signOutButton
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
    }

    var meHeader: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color("DudeCupGreen").opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: me?.avatarName ?? "person.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color("DudeCupGreen"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(me?.name ?? "Guest")
                    .font(.system(size: 24, weight: .black)).fontWidth(.compressed)
                    .foregroundStyle(.white)
                Text(me?.team ?? "")
                    .font(.system(size: 10, weight: .heavy)).tracking(2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    var menuLinks: some View {
        VStack(spacing: 0) {
            meLink(icon: "person.crop.circle.fill",  color: Color("DudeCupGreen"),  label: "MY PROFILE") {
                if let me { AnyView(PlayerProfileView(player: me)) } else { AnyView(EmptyView()) }
            }
            divider
            meLink(icon: "calendar",                 color: .blue,                  label: "SCHEDULE") {
                AnyView(ScheduleView())
            }
            divider
            meLink(icon: "person.3.fill",            color: .purple,                label: "PLAYERS") {
                AnyView(PlayersView())
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    var commishLink: some View {
        VStack(spacing: 0) {
            meLink(icon: "key.fill", color: .red, label: "COMMISH DASHBOARD") {
                AnyView(CommishDashboardView())
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    var signOutButton: some View {
        Button { authManager.signOut() } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                Text("SIGN OUT")
                    .font(.system(size: 13, weight: .heavy)).tracking(2)
                Spacer()
            }
            .foregroundStyle(Color.red.opacity(0.7))
            .padding(.horizontal, 20).padding(.vertical, 18)
        }
        .padding(.top, 28)
    }

    var divider: some View {
        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 56)
    }

    func meLink(icon: String, color: Color, label: String, destination: @escaping () -> AnyView) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15)).frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                }
                Text(label)
                    .font(.system(size: 14, weight: .heavy)).tracking(0.5).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Home View

struct HomeView: View {
    @Environment(TournamentManager.self) private var manager
    @State private var timeRemaining: TimeInterval = 0
    @State private var secondsOpacity: Double = 1.0
    @State private var venueBannerDismissed = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var nextEvent: TournamentEvent? {
        manager.schedule
            .filter { $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    var sortedAnnouncements: [Announcement] {
        manager.announcements.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ── HERO HEADER ──────────────────────────────────
                        heroHeader

                        // ── COUNTDOWN ────────────────────────────────────
                        if let event = nextEvent {
                            countdownBlock(event)
                        }

                        // ── VENUE BANNER ─────────────────────────────────
                        if !venueBannerDismissed {
                            venueBanner
                        }

                        // ── ZONE 2: ANNOUNCEMENTS ────────────────────────
                        announcementsBlock

                        // ── ZONE 2/3 DIVIDER ─────────────────────────────
                        if manager.activeRound > 0 {
                            zoneDivider
                        }

                        // ── ZONE 3: LIVE ACTIVITY FEED ───────────────────
                        LiveFeedSection()

                        Spacer(minLength: 40)
                    }
                }
            }
            .onReceive(timer) { _ in
                if let event = nextEvent {
                    timeRemaining = event.startTime.timeIntervalSince(Date())
                }
                // Tick the seconds opacity for a clean flash — no layout impact
                secondsOpacity = 0.4
                withAnimation(.easeIn(duration: 0.4)) {
                    secondsOpacity = 1.0
                }
            }
            .navigationBarHidden(true)
        }
    }

    // ── HERO ─────────────────────────────────────────────────────────────────
    var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Background — deep black with a faint orange glow
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity)
                .overlay(
                    RadialGradient(
                        colors: [Color("DudeCupGreen").opacity(0.25), Color.clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 280
                    )
                )

            VStack(spacing: 0) {
                // Kicker label
                Text("EST. 2014  •  ANNUAL INVITATIONAL")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(Color("DudeCupGreen").opacity(0.7))
                    .padding(.top, 20)

                // Main title — compressed black weight for that zine poster feel
                Text("THE")
                    .font(.system(size: 72, weight: .black))
                    .fontWidth(.compressed)
                    .tracking(-2)
                    .foregroundStyle(.white)
                    .padding(.bottom, -20)

                Text("DUDE")
                    .font(.system(size: 100, weight: .black))
                    .fontWidth(.compressed)
                    .tracking(-3)
                    .foregroundStyle(Color("DudeCupGreen"))
                    .padding(.bottom, -24)

                Text("CUP")
                    .font(.system(size: 100, weight: .black))
                    .fontWidth(.compressed)
                    .tracking(-3)
                    .foregroundStyle(.white)

                // Year badge
                Text("2026")
                    .font(.system(size: 18, weight: .black))
                    .tracking(8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color("DudeCupGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.top, 12)
                    .padding(.bottom, 28)
            }
        }
    }

    // ── COUNTDOWN ────────────────────────────────────────────────────────────
    func countdownBlock(_ event: TournamentEvent) -> some View {
        VStack(spacing: 0) {

            // Divider stripe — orange rule
            Rectangle()
                .fill(Color("DudeCupGreen"))
                .frame(height: 3)

            ZStack {
                Color(white: 0.06)

                VStack(spacing: 16) {
                    Text("NEXT UP")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(5)
                        .foregroundStyle(Color("DudeCupGreen"))
                        .padding(.top, 24)

                    // Event name
                    Text(event.title.uppercased())
                        .font(.system(size: 28, weight: .black))
                        .fontWidth(.compressed)
                        .tracking(1)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(event.location.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.4))

                    // Big countdown timer
                    HStack(spacing: 0) {
                        countdownUnit(value: days, label: "DAYS")
                        countdownSeparator
                        countdownUnit(value: hours, label: "HRS")
                        countdownSeparator
                        countdownUnit(value: minutes, label: "MIN")
                        countdownSeparator
                        countdownUnit(value: seconds, label: "SEC")
                    }
                    .padding(.vertical, 8)

                    // Event date line
                    Text(event.startTime, style: .date)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.bottom, 24)
                }
            }

            Rectangle()
                .fill(Color("DudeCupGreen"))
                .frame(height: 3)
        }
    }

    func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", max(0, value)))
                .font(.system(size: 52, weight: .black))
                .fontWidth(.compressed)
                .tracking(-2)
                .foregroundStyle(Color("DudeCupGreen"))
                .monospacedDigit()
                .opacity(label == "SEC" ? secondsOpacity : 1.0)

            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    var countdownSeparator: some View {
        Text(":")
            .font(.system(size: 40, weight: .black))
            .foregroundStyle(Color("DudeCupGreen").opacity(0.4))
            .padding(.bottom, 14)
    }

    var days: Int { max(0, Int(timeRemaining)) / 86400 }
    var hours: Int { (max(0, Int(timeRemaining)) % 86400) / 3600 }
    var minutes: Int { (max(0, Int(timeRemaining)) % 3600) / 60 }
    var seconds: Int { max(0, Int(timeRemaining)) % 60 }

    // ── ZONE DIVIDER ─────────────────────────────────────────────────────────
    var zoneDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
            Text("LIVE FEED")
                .font(.system(size: 8, weight: .heavy))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.15))
                .fixedSize()
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 0)
    }

    // ── ANNOUNCEMENTS ────────────────────────────────────────────────────────
    // ── VENUE BANNER ─────────────────────────────────────────────────────────
    var venueBanner: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.red)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTION REQUIRED")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(Color.red)
                    Text("Call Wayne Doyel to book your reservation and pay initial deposit ($180)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ventana Canyon · (520) 577-4092")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { venueBannerDismissed = true }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(8)
                }
            }
            .padding(14)

            Button {
                if let url = URL(string: "tel:5205774092") { UIApplication.shared.open(url) }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill").font(.system(size: 13, weight: .bold))
                    Text("CALL NOW — WAYNE DOYEL")
                        .font(.system(size: 12, weight: .heavy)).tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.red)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10, topTrailingRadius: 0))
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    var announcementsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Section header
            HStack {
                Text("ANNOUNCEMENTS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(5)
                    .foregroundStyle(Color("DudeCupGreen"))

                Spacer()

                Text("\(sortedAnnouncements.count)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)

            if sortedAnnouncements.isEmpty {
                // Empty state — on-brand
                VStack(spacing: 12) {
                    Text("📢")
                        .font(.system(size: 48))
                    Text("NO ANNOUNCEMENTS YET")
                        .font(.system(size: 14, weight: .heavy))
                        .fontWidth(.compressed)
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.3))
                    Text("The Commish will blast updates here.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedAnnouncements) { announcement in
                        announcementCard(announcement)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    func announcementCard(_ announcement: Announcement) -> some View {
        HStack(spacing: 0) {
            // Orange left-border accent — the "zine sidebar"
            Rectangle()
                .fill(Color("DudeCupGreen"))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(announcement.title.uppercased())
                        .font(.system(size: 15, weight: .black))
                        .fontWidth(.compressed)
                        .tracking(1)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Text(announcement.date, style: .relative)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 2)
                }

                Text(announcement.message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(announcement.author.uppercased())")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Color("DudeCupGreen").opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}


// MARK: - Players View

struct PlayersView: View {
    @Environment(TournamentManager.self) private var manager
    @State private var searchText = ""

    var sortedPlayers: [Player] {
        let all = manager.players.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("PLAYERS")
                            .font(.system(size: 32, weight: .black))
                            .fontWidth(.compressed)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(manager.players.count)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color("DudeCupGreen"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color("DudeCupGreen").opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                        TextField("", text: $searchText, prompt: Text("Search players...").foregroundStyle(.white.opacity(0.25)))
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                                NavigationLink(destination: PlayerProfileView(player: player)) {
                                    PlayerRowView(player: player)
                                }
                                .buttonStyle(.plain)
                                if index < sortedPlayers.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(height: 1)
                                        .padding(.leading, 76)
                                }
                            }
                        }
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

struct PlayerRowView: View {
    let player: Player

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 46, height: 46)
                Text(player.name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined())
                    .font(.system(size: 15, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(Color("DudeCupGreen"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(player.team.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.25))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.handicap)")
                    .font(.system(size: 18, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(.white.opacity(0.6))
                Text("HCP")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.2))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Schedule View

struct ScheduleView: View {
    @Environment(TournamentManager.self) private var manager

    // Regular (non-bonus) events sorted chronologically
    var regularEvents: [TournamentEvent] {
        manager.schedule
            .filter { !$0.isBonus }
            .sorted { $0.startTime < $1.startTime }
    }

    // Bonus Day events sorted chronologically
    var bonusEvents: [TournamentEvent] {
        manager.schedule
            .filter { $0.isBonus }
            .sorted { $0.startTime < $1.startTime }
    }

    var publishedSheets: [TeeSheet] {
        manager.teeSheets.filter { $0.isPublished }
            .sorted { $0.roundNumber < $1.roundNumber }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {

                        // ── Header ──────────────────────────────────────
                        HStack {
                            Text("SCHEDULE")
                                .font(.system(size: 32, weight: .black))
                                .fontWidth(.compressed)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                        // ── Accordion Sections ───────────────────────────
                        VStack(spacing: 10) {

                            // 1 — Tee Times
                            ScheduleAccordion(
                                icon: "clock.fill",
                                title: "TEE TIMES",
                                badge: publishedSheets.isEmpty ? nil : "\(publishedSheets.count) ROUND\(publishedSheets.count == 1 ? "" : "S")",
                                emptyMessage: publishedSheets.isEmpty ? "Not yet posted by the Commish." : nil
                            ) {
                                AnyView(
                                    VStack(spacing: 8) {
                                        ForEach(publishedSheets) { sheet in
                                            TeeSheetRoundCard(sheet: sheet)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 4)
                                )
                            }

                            // 2 — Events
                            ScheduleAccordion(
                                icon: "calendar",
                                title: "EVENTS",
                                badge: "\(regularEvents.count)",
                                emptyMessage: regularEvents.isEmpty ? "No events scheduled yet." : nil
                            ) {
                                AnyView(
                                    VStack(spacing: 0) {
                                        ForEach(Array(regularEvents.enumerated()), id: \.element.id) { idx, event in
                                            scheduleRow(event: event)
                                            if idx < regularEvents.count - 1 {
                                                Rectangle()
                                                    .fill(Color.white.opacity(0.05))
                                                    .frame(height: 1)
                                                    .padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(Color(white: 0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 4)
                                )
                            }

                            // 3 — Bonus Day (only rendered if bonus events exist)
                            if !bonusEvents.isEmpty {
                                ScheduleAccordion(
                                    icon: "star.fill",
                                    title: "BONUS DAY",
                                    badge: "\(bonusEvents.count)",
                                    accentColor: Color(red: 1.0, green: 0.84, blue: 0.0),
                                    emptyMessage: nil
                                ) {
                                    AnyView(
                                        VStack(spacing: 0) {
                                            ForEach(Array(bonusEvents.enumerated()), id: \.element.id) { idx, event in
                                                scheduleRow(event: event, accentColor: Color(red: 1.0, green: 0.84, blue: 0.0))
                                                if idx < bonusEvents.count - 1 {
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.05))
                                                        .frame(height: 1)
                                                        .padding(.leading, 56)
                                                }
                                            }
                                        }
                                        .background(Color(white: 0.07))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal, 4)
                                        .padding(.bottom, 4)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }

    // ── Event Row ──────────────────────────────────────────────────────────

    func scheduleRow(event: TournamentEvent, accentColor: Color = Color("DudeCupGreen")) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: event.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.uppercased())
                    .font(.system(size: 13, weight: .heavy))
                    .fontWidth(.compressed)
                    .tracking(0.5)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(event.location)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.white.opacity(0.2))
                    Text(event.startTime, style: .time)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

// MARK: - Schedule Accordion Component

struct ScheduleAccordion<Content: View>: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var accentColor: Color = Color("DudeCupGreen")
    var emptyMessage: String? = nil
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            Button {
                withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    // Icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accentColor.opacity(isExpanded ? 0.2 : 0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor.opacity(isExpanded ? 1.0 : 0.7))
                    }

                    // Title
                    Text(title)
                        .font(.system(size: 15, weight: .black))
                        .fontWidth(.compressed)
                        .tracking(1)
                        .foregroundStyle(isExpanded ? .white : .white.opacity(0.7))

                    Spacer()

                    // Badge
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(duration: 0.28, bounce: 0.15), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(white: isExpanded ? 0.1 : 0.08))
            }
            .buttonStyle(.plain)

            // ── Expanded Content ──────────────────────────────────────
            if isExpanded {
                Rectangle()
                    .fill(accentColor.opacity(0.15))
                    .frame(height: 1)

                if let msg = emptyMessage {
                    // Empty state
                    VStack(spacing: 8) {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color(white: 0.07))
                } else {
                    VStack(spacing: 0) {
                        content()
                            .padding(.top, 10)
                    }
                    .background(Color(white: 0.07))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isExpanded ? accentColor.opacity(0.2) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .animation(.spring(duration: 0.28, bounce: 0.15), value: isExpanded)
    }
}


// MARK: - Leaderboard View

struct LeaderboardView: View {
    @Environment(TournamentManager.self) private var manager

    // Calculate points ONCE per player — prevents the infinite math loop
    var rankedPlayers: [(player: Player, points: Int)] {
        manager.players.map { player in
            let points = stablefordPoints(for: player)
            return (player, points)
        }.sorted { $0.points > $1.points }
    }

    func stablefordPoints(for player: Player) -> Int {
        guard let score = manager.scores.first(where: { $0.playerId == player.id }) else { return 0 }
        return manager.stablefordTotal(score: score, player: player)
    }

    func mostRecentBadge(for player: Player) -> String? {
        manager.playerBadges[player.id]
    }

    // Initials helper
    func initials(_ name: String) -> String {
        name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    leaderboardHeader
                    podiumSection
                    rankListSection
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // ── HEADER ───────────────────────────────────────────────────────────────
    var leaderboardHeader: some View {
        ZStack {
            Color.black
            // Subtle orange gradient wash from center
            RadialGradient(
                colors: [Color("DudeCupGreen").opacity(0.18), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )

            VStack(spacing: 4) {
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(Color("DudeCupGreen"))
                    .padding(.top, 20)

                Text("THE DUDE CUP")
                    .font(.system(size: 42, weight: .black))
                    .fontWidth(.compressed)
                    .tracking(-1)
                    .foregroundStyle(.white)

                Text("2026")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // ── PODIUM ───────────────────────────────────────────────────────────────
    @ViewBuilder
    var podiumSection: some View {
        if rankedPlayers.count >= 3 {
            ZStack(alignment: .bottom) {
                // Dark podium floor
                Rectangle()
                    .fill(Color(white: 0.06))
                    .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    // The three cards — 2nd | 1st | 3rd, aligned to bottom
                    HStack(alignment: .bottom, spacing: 10) {

                        // ── 2nd place ──
                        podiumPillar(
                            player: rankedPlayers[1].player,
                            points: rankedPlayers[1].points,
                            position: 2,
                            pillarHeight: 56,
                            avatarSize: 60
                        )

                        // ── 1st place ──
                        podiumPillar(
                            player: rankedPlayers[0].player,
                            points: rankedPlayers[0].points,
                            position: 1,
                            pillarHeight: 88,
                            avatarSize: 76
                        )

                        // ── 3rd place ──
                        podiumPillar(
                            player: rankedPlayers[2].player,
                            points: rankedPlayers[2].points,
                            position: 3,
                            pillarHeight: 40,
                            avatarSize: 56
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                }
                .padding(.bottom, 0)
            }

            // Solid orange divider under podium
            Rectangle()
                .fill(Color("DudeCupGreen"))
                .frame(height: 3)
        }
    }

    func podiumPillar(player: Player, points: Int, position: Int, pillarHeight: CGFloat, avatarSize: CGFloat) -> some View {
        VStack(spacing: 0) {

            // ── Floating card above the pillar ──
            VStack(spacing: 6) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(position == 1 ? Color("DudeCupGreen") : Color(white: 0.18))
                        .frame(width: avatarSize, height: avatarSize)

                    Text(initials(player.name))
                        .font(.system(size: position == 1 ? 26 : 20, weight: .black))
                        .fontWidth(.compressed)
                        .foregroundStyle(position == 1 ? .black : .white)
                }
                // Winner crown
                if position == 1 {
                    Text("👑")
                        .font(.system(size: 20))
                        .offset(y: -avatarSize - 4)
                        .padding(.bottom, -avatarSize - 2)
                }

                // Name
                Text(player.name.components(separatedBy: " ").first ?? player.name)
                    .font(.system(size: position == 1 ? 14 : 12, weight: .black))
                    .fontWidth(.compressed)
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Points
                Text("\(points)")
                    .font(.system(size: position == 1 ? 28 : 22, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(position == 1 ? Color("DudeCupGreen") : .white.opacity(0.6))

                Text("PTS")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)

            // ── The actual podium block ──
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(position == 1
                          ? Color("DudeCupGreen")
                          : Color(white: position == 2 ? 0.16 : 0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: pillarHeight)

                Text(positionLabel(position))
                    .font(.system(size: position == 1 ? 36 : 28, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(position == 1 ? .black : .white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    func positionLabel(_ position: Int) -> String {
        switch position {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(position)"
        }
    }

    // ── RANKED LIST ──────────────────────────────────────────────────────────
    var rankListSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("FULL STANDINGS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(5)
                    .foregroundStyle(Color("DudeCupGreen"))

                Spacer()

                Text("\(rankedPlayers.count) PLAYERS")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 14)

            // Rows
            VStack(spacing: 0) {
                ForEach(Array(rankedPlayers.enumerated()), id: \.element.player.id) { index, item in
                    NavigationLink(destination: PlayerProfileView(player: item.player)) {
                        rankRow(index: index, item: item)
                    }
                    .buttonStyle(.plain)

                    if index < rankedPlayers.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.leading, index < 3 ? 0 : 56)
                    }
                }
            }
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    func rankRow(index: Int, item: (player: Player, points: Int)) -> some View {
        let isTop3 = index < 3
        let isFirst = index == 0

        return HStack(spacing: 14) {

            // Rank number / colored block for top 3
            if isTop3 {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFirst ? Color("DudeCupGreen") : Color(white: 0.15))
                        .frame(width: 36, height: 36)

                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .black))
                        .fontWidth(.compressed)
                        .foregroundStyle(isFirst ? .black : .white)
                }
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(width: 36)
                    .monospacedDigit()
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(isFirst ? Color("DudeCupGreen").opacity(0.2) : Color(white: 0.14))
                    .frame(width: 38, height: 38)
                Text(initials(item.player.name))
                    .font(.system(size: 13, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(isFirst ? Color("DudeCupGreen") : .white.opacity(0.6))
            }

            // Name + team
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.player.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    if let badge = mostRecentBadge(for: item.player) {
                        Text(badge)
                            .font(.system(size: 12))
                    }
                }

                Text(item.player.team.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.25))
            }

            Spacer()

            // Points
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(item.points)")
                    .font(.system(size: 22, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(isFirst ? Color("DudeCupGreen") : .white.opacity(0.8))
                    .monospacedDigit()

                Text("PTS")
                    .font(.system(size: 7, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.2))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isTop3 ? 14 : 11)
        .background(isFirst ? Color("DudeCupGreen").opacity(0.06) : Color.clear)
    }
}


// MARK: - My Round View

struct MyRoundView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager
    @State private var selectedHole = 1
    
    var currentPlayer: Player? {
        authManager.currentPlayer
    }
    
    var playerScore: Score? {
        guard let player = currentPlayer else { return nil }
        return manager.scores.first { $0.playerId == player.id }
    }
    
    var currentRound: RoundScore? {
        playerScore?.rounds.last
    }
    
    var currentCourse: Course? {
        guard let round = currentRound else { return nil }
        return manager.courses.first { $0.id == round.courseId }
    }
    
    func strokesForHole(_ holeNumber: Int) -> Int {
        guard let round = currentRound else { return 0 }
        let index = holeNumber - 1
        return index < round.holes.count ? round.holes[index].strokes : 0
    }
    
    func saveScore(hole: Int, strokes: Int) {
        guard let player = currentPlayer,
              let round = currentRound else { return }
        manager.saveHoleScore(playerId: player.id, roundNumber: round.roundNumber, holeIndex: hole - 1, strokes: strokes)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let course = currentCourse, let round = currentRound {
                VStack(spacing: 0) {

                    // ── Fixed scorecard grid at top ──
                    scorecardGrid(course: course, round: round)

                    Rectangle()
                        .fill(Color("DudeCupGreen"))
                        .frame(height: 2)

                    // ── Hole input fills remaining space ──
                    HoleInputView(
                        hole: selectedHole,
                        course: course,
                        currentStrokes: strokesForHole(selectedHole),
                        onStrokesChange: { strokes in
                            saveScore(hole: selectedHole, strokes: strokes)
                        },
                        onPrevious: {
                            if selectedHole > 1 { selectedHole -= 1 }
                        },
                        onNext: {
                            if selectedHole < 18 { selectedHole += 1 }
                        },
                        isStrokeHole: manager.courses.first { $0.id == round.courseId }?.strokeHoles(for: currentPlayer?.handicap ?? 0).contains(selectedHole) ?? false,
                        isRandom9Hole: manager.isRandom9Hole(round: round.roundNumber, hole: selectedHole),
                        isAttested: round.isAttested
                    )

                    // ── Bottom action bar ──
                    bottomActionBar(round: round)
                }
            } else {
                // On-brand empty state
                VStack(spacing: 16) {
                    Text("⛳️")
                        .font(.system(size: 64))
                    Text("NO ACTIVE ROUND")
                        .font(.system(size: 22, weight: .black))
                        .fontWidth(.compressed)
                        .tracking(3)
                        .foregroundStyle(.white)
                    Text("Check the schedule for tee times.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .navigationBarHidden(true)
    }

    // ── SCORECARD GRID ────────────────────────────────────────────────────────
    func scorecardGrid(course: Course, round: RoundScore) -> some View {
        VStack(spacing: 0) {

            // Course name header
            HStack {
                Text(course.name.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(Color("DudeCupGreen"))
                Spacer()
                Text("ROUND \(round.roundNumber)")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(white: 0.08))

            // Front nine
            HStack(spacing: 0) {
                ForEach(1...9, id: \.self) { hole in
                    scorecardCell(for: hole - 1, course: course, round: round)
                }
                totalCell(holes: 0..<9, label: "OUT", round: round)
            }
            .background(Color(white: 0.05))

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)

            // Back nine
            HStack(spacing: 0) {
                ForEach(10...18, id: \.self) { hole in
                    scorecardCell(for: hole - 1, course: course, round: round)
                }
                totalCell(holes: 9..<18, label: "IN", round: round)
            }
            .background(Color(white: 0.05))

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)

            // Totals row
            HStack(spacing: 0) {
                Text("TOTAL")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                Text(round.totalGross > 0 ? "\(round.totalGross)" : "–")
                    .font(.system(size: 16, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(Color("DudeCupGreen"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .background(Color(white: 0.08))
        }
    }

    func scorecardCell(for index: Int, course: Course, round: RoundScore) -> some View {
        let holeNumber = index + 1
        let strokes = index < round.holes.count ? round.holes[index].strokes : 0
        let isStroke = course.strokeHoles(for: currentPlayer?.handicap ?? 0).contains(holeNumber)
        let isR9 = manager.isRandom9Hole(round: round.roundNumber, hole: holeNumber)
        let isSelected = selectedHole == holeNumber
        let par = course.holes.first(where: { $0.number == holeNumber })?.par ?? 4
        let scoreColor = scoreRelativeColor(strokes: strokes, par: par)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedHole = holeNumber
        } label: {
            VStack(spacing: 1) {
                // Hole number
                Text("\(holeNumber)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color("DudeCupGreen") : Color.clear)

                // Score
                Text(strokes > 0 ? "\(strokes)" : "·")
                    .font(.system(size: 14, weight: .black))
                    .fontWidth(.compressed)
                    .foregroundStyle(strokes > 0 ? scoreColor : .white.opacity(0.15))
                    .padding(.bottom, 2)

                // Indicator dots
                HStack(spacing: 2) {
                    if isStroke {
                        Circle().fill(Color("DudeCupGreen")).frame(width: 3, height: 3)
                    }
                    if isR9 {
                        Circle().fill(Color.yellow).frame(width: 3, height: 3)
                    }
                    if !isStroke && !isR9 {
                        Color.clear.frame(width: 3, height: 3)
                    }
                }
                .padding(.bottom, 3)
            }
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color("DudeCupGreen").opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    func totalCell(holes: Range<Int>, label: String, round: RoundScore) -> some View {
        let total = holes.reduce(0) { sum, index in
            sum + (index < round.holes.count ? round.holes[index].strokes : 0)
        }
        return VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(white: 0.1))

            Text(total > 0 ? "\(total)" : "–")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 2)

            Color.clear.frame(width: 3, height: 3).padding(.bottom, 3)
        }
        .frame(maxWidth: .infinity)
    }

    // ── BOTTOM ACTION BAR ─────────────────────────────────────────────────────
    @ViewBuilder
    func bottomActionBar(round: RoundScore) -> some View {
        if round.isAttested {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("ROUND LOCKED & ATTESTED")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
            }
            .foregroundStyle(Color("DudeCupGreen"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("DudeCupGreen").opacity(0.08))
            .overlay(Rectangle().fill(Color("DudeCupGreen").opacity(0.3)).frame(height: 1), alignment: .top)

        } else if round.isComplete {
            Button {
                if let player = currentPlayer {
                    manager.attestRound(playerId: player.id, roundNumber: round.roundNumber)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .black))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ATTEST & LOCK SCORECARD")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(1)
                        Text("This cannot be undone")
                            .font(.system(size: 10))
                            .opacity(0.7)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.6)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.85))
            }
            .overlay(Rectangle().fill(Color.red).frame(height: 2), alignment: .top)
        }
    }

    // ── SCORE COLOR HELPERS ───────────────────────────────────────────────────
    func scoreRelativeColor(strokes: Int, par: Int) -> Color {
        guard strokes > 0 else { return .white.opacity(0.2) }
        let diff = strokes - par
        switch diff {
        case ..<(-1): return Color(red: 0.3, green: 0.7, blue: 1.0)   // Eagle+ — blue
        case -1:      return Color("DudeCupGreen")                      // Birdie — orange
        case 0:       return .white                                     // Par — white
        case 1:       return Color(red: 1.0, green: 0.85, blue: 0.3)  // Bogey — yellow
        default:      return Color(red: 1.0, green: 0.35, blue: 0.35) // Double+ — red
        }
    }
}

// MARK: - Hole Input View

struct HoleInputView: View {
    let hole: Int
    let course: Course
    let currentStrokes: Int
    let onStrokesChange: (Int) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let isStrokeHole: Bool
    let isRandom9Hole: Bool
    let isAttested: Bool

    @State private var strokes: Int

    init(hole: Int, course: Course, currentStrokes: Int, onStrokesChange: @escaping (Int) -> Void, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void, isStrokeHole: Bool, isRandom9Hole: Bool, isAttested: Bool) {
        self.hole = hole
        self.course = course
        self.currentStrokes = currentStrokes
        self.onStrokesChange = onStrokesChange
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.isStrokeHole = isStrokeHole
        self.isRandom9Hole = isRandom9Hole
        self.isAttested = isAttested
        _strokes = State(initialValue: currentStrokes)
    }

    var holeInfo: CourseHole? {
        course.holes.first { $0.number == hole }
    }

    var par: Int { holeInfo?.par ?? 4 }

    var scoreLabel: (text: String, color: Color) {
        guard strokes > 0 else { return ("TAP + TO START", Color.white.opacity(0.2)) }
        let diff = strokes - par
        switch diff {
        case ..<(-2): return ("ALBATROSS 🦅🦅", Color(red: 0.3, green: 0.7, blue: 1.0))
        case -2:      return ("EAGLE 🦅", Color(red: 0.3, green: 0.7, blue: 1.0))
        case -1:      return ("BIRDIE 🐦", Color("DudeCupGreen"))
        case 0:       return ("PAR", .white)
        case 1:       return ("BOGEY", Color(red: 1.0, green: 0.85, blue: 0.3))
        case 2:       return ("DOUBLE BOGEY", Color(red: 1.0, green: 0.55, blue: 0.35))
        default:      return ("+\(diff)", Color(red: 1.0, green: 0.3, blue: 0.3))
        }
    }

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {

                // ── Hole info bar ─────────────────────────────────────────
                HStack(alignment: .center) {

                    // Hole number + badges
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOLE")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(hole)")
                            .font(.system(size: 48, weight: .black))
                            .fontWidth(.compressed)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }

                    Spacer()

                    // Badge tags
                    VStack(alignment: .trailing, spacing: 6) {
                        if let info = holeInfo {
                            HStack(spacing: 8) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("PAR")
                                        .font(.system(size: 9, weight: .heavy))
                                        .tracking(3)
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("\(info.par)")
                                        .font(.system(size: 32, weight: .black))
                                        .fontWidth(.compressed)
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("YDS")
                                        .font(.system(size: 9, weight: .heavy))
                                        .tracking(3)
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("\(info.yardage)")
                                        .font(.system(size: 32, weight: .black))
                                        .fontWidth(.compressed)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            if isStrokeHole {
                                Text("STROKE")
                                    .font(.system(size: 8, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color("DudeCupGreen"))
                                    .clipShape(Capsule())
                            }
                            if isRandom9Hole {
                                Text("RANDOM 9")
                                    .font(.system(size: 8, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.yellow)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

                // ── Big score display ────────────────────────────────────
                Spacer()

                VStack(spacing: 8) {
                    // The number
                    Text(strokes > 0 ? "\(strokes)" : "–")
                        .font(.system(size: 120, weight: .black))
                        .fontWidth(.compressed)
                        .tracking(-4)
                        .foregroundStyle(strokes > 0 ? scoreLabel.color : .white.opacity(0.1))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.2), value: strokes)

                    // Score label pill
                    Text(scoreLabel.text)
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(scoreLabel.color)
                        .opacity(0.9)
                }

                Spacer()

                // ── Stroke buttons ───────────────────────────────────────
                HStack(spacing: 0) {

                    // MINUS
                    Button {
                        guard strokes > 0 && !isAttested else { return }
                        strokes -= 1
                        onStrokesChange(strokes)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(strokes == 0 || isAttested
                                      ? Color(white: 0.07)
                                      : Color(white: 0.1))
                            Image(systemName: "minus")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(strokes == 0 || isAttested
                                                 ? .white.opacity(0.1)
                                                 : .white.opacity(0.6))
                        }
                    }
                    .disabled(strokes == 0 || isAttested)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)

                    Rectangle().fill(Color.black).frame(width: 2)

                    // PLUS
                    Button {
                        guard !isAttested else { return }
                        strokes += 1
                        onStrokesChange(strokes)
                        // First stroke gets a heavier feedback
                        let style: UIImpactFeedbackGenerator.FeedbackStyle = strokes == 1 ? .heavy : .medium
                        UIImpactFeedbackGenerator(style: style).impactOccurred()
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(isAttested ? Color(white: 0.07) : Color("DudeCupGreen").opacity(0.85))
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(isAttested ? .white.opacity(0.1) : .black)
                        }
                    }
                    .disabled(isAttested)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                }

                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

                // ── Prev / Next navigation ───────────────────────────────
                HStack(spacing: 0) {
                    Button(action: {
                        onPrevious()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("PREV")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(2)
                        }
                        .foregroundStyle(hole == 1 ? .white.opacity(0.1) : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                    .disabled(hole == 1)

                    Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)

                    // Hole progress dots
                    HStack(spacing: 4) {
                        ForEach(1...18, id: \.self) { h in
                            Circle()
                                .fill(h == hole
                                      ? Color("DudeCupGreen")
                                      : strokesForDot(h) > 0
                                          ? Color.white.opacity(0.4)
                                          : Color.white.opacity(0.1))
                                .frame(width: h == hole ? 7 : 4, height: h == hole ? 7 : 4)
                                .animation(.spring(duration: 0.2), value: hole)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)

                    Button(action: {
                        onNext()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 8) {
                            Text("NEXT")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(2)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(hole == 18 ? .white.opacity(0.1) : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                    .disabled(hole == 18)
                }
                .background(Color(white: 0.05))
            }
        }
        .onChange(of: currentStrokes) { _, newValue in
            strokes = newValue
        }
    }

    // Used by the progress dots to check if a hole has been scored
    func strokesForDot(_ holeNumber: Int) -> Int {
        let index = holeNumber - 1
        let holes = course.holes
        guard index < holes.count else { return 0 }
        return 0 // dots just show visited — actual data lives in parent
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}

// MARK: - Commish Dashboard View

struct CommishDashboardView: View {
    @Environment(TournamentManager.self) private var manager
    @State private var showingRandom9Alert = false
    @State private var showingAnnouncementSheet = false
    @State private var showingEndTournamentAlert = false
    @State private var showingResetAlert = false
    @State private var isResetting = false
    @State private var roundToOpen: Int = 1
    @State private var showingOpenRoundAlert = false
    @State private var isOpeningRound = false

    var body: some View {
        Form {
            Section(header: Text("Round Management"), footer: Text("Opening a round creates blank scorecards for every player and sets it as the active round. Players can then enter scores in My Round.")) {

                // Round picker
                Picker("Open Round", selection: $roundToOpen) {
                    ForEach(1...4, id: \.self) { n in
                        Text("Round \(n)  —  \(n % 2 == 1 ? "Canyon" : "Mountain")").tag(n)
                    }
                }

                Button {
                    showingOpenRoundAlert = true
                } label: {
                    HStack {
                        if isOpeningRound {
                            ProgressView().tint(Color("DudeCupGreen"))
                            Text("Opening Round \(roundToOpen)...").fontWeight(.bold)
                        } else {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(Color("DudeCupGreen"))
                            Text("Open Round \(roundToOpen)")
                                .fontWeight(.bold)
                                .foregroundStyle(Color("DudeCupGreen"))
                        }
                    }
                }
                .disabled(isOpeningRound)

                if manager.activeRound > 0 {
                    HStack {
                        Text("Currently Active")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Round \(manager.activeRound)")
                            .fontWeight(.bold)
                            .foregroundStyle(Color("DudeCupGreen"))
                    }
                }

                Button(role: .destructive) {
                    showingEndTournamentAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("End Tournament & Finalize", systemImage: "flag.checkered")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
            }

            Section(header: Text("Tournament Controls"), footer: Text("Generating new holes overwrites the previous selection and pushes live to all players.")) {
                Button(role: .destructive) {
                    showingRandom9Alert = true
                } label: {
                    Label("Generate Random 9 Holes", systemImage: "dice.fill")
                }

                NavigationLink(destination: AdminCTPListView()) {
                    Label("CTP Adjudicator", systemImage: "flag.fill")
                        .foregroundStyle(.primary)
                }
            }

            Section(header: Text("Communications")) {
                Button {
                    showingAnnouncementSheet = true
                } label: {
                    Label("Push New Announcement", systemImage: "megaphone.fill")
                        .foregroundStyle(.primary)
                }
            }

            Section(header: Text("Tee Sheets")) {
                NavigationLink(destination: TeeSheetBuilderView()) {
                    Label("Tee Sheet Builder", systemImage: "calendar.badge.plus")
                        .foregroundStyle(.primary)
                }
            }

            Section(header: Text("Scoring Admin")) {
                NavigationLink(destination: AdminPlayerListView()) {
                    Label("Edit Player Scores", systemImage: "pencil.and.list.clipboard")
                        .foregroundStyle(.primary)
                }
            }

            Section(header: Text("⚠️ Danger Zone"), footer: Text("Permanently deletes ALL scores, bets, CTP entries, Random 9 selection, and announcements from Firebase. Cannot be undone.")) {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    HStack {
                        if isResetting {
                            ProgressView().tint(.red)
                            Text("Resetting...").fontWeight(.bold)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Reset All Tournament Data").fontWeight(.bold)
                        }
                    }
                }
                .disabled(isResetting)
            }
        }
        .navigationTitle("Commish Mode")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Open Round \(roundToOpen)?", isPresented: $showingOpenRoundAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open It") {
                isOpeningRound = true
                Task {
                    await manager.openRound(roundToOpen)
                    await MainActor.run { isOpeningRound = false }
                }
            }
        } message: {
            Text("This will create blank scorecards for all \(manager.players.count) players on \(roundToOpen % 2 == 1 ? "Canyon" : "Mountain") and set Round \(roundToOpen) as the active round.")
        }
        .alert("Generate Random 9?", isPresented: $showingRandom9Alert) {
            Button("Cancel", role: .cancel) { }
            Button("Generate", role: .destructive) { manager.generateRandom9() }
        } message: {
            Text("This will instantly select 9 random holes and update the live leaderboard. Are you sure?")
        }
        .alert("End The Dude Cup?", isPresented: $showingEndTournamentAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Finalize Results", role: .destructive) {
                manager.updateTournamentState(activeRound: manager.activeRound, isComplete: true)
                manager.pushAnnouncement(
                    title: "🏆 The Tournament is Final!",
                    message: "The results are locked in. Check the leaderboard for final standings and payouts!",
                    author: "The Commish"
                )
            }
        } message: {
            Text("This will officially lock the entire tournament, finalize all leaderboards, and push an announcement to all players. This cannot be undone.")
        }
        .alert("Reset ALL Data?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                isResetting = true
                Task {
                    await manager.resetAllData()
                    await MainActor.run { isResetting = false }
                }
            }
        } message: {
            Text("This will permanently wipe all scores, bets, CTP entries, Random 9, and announcements from Firebase. Use this before a test run or at the start of a new tournament.")
        }
        .sheet(isPresented: $showingAnnouncementSheet) {
            AnnouncementFormView()
        }
    }
}

// MARK: - Announcement Form (The Megaphone)

struct AnnouncementFormView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var message = ""
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Message Details"), footer: Text("This will instantly push to every player's Home screen.")) {
                    TextField("Title (e.g. Frost Delay)", text: $title)
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("New Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Push Live") {
                        if let author = authManager.currentPlayer?.name {
                            manager.pushAnnouncement(title: title, message: message, author: author)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Admin Scoring Views

struct AdminPlayerListView: View {
    @Environment(TournamentManager.self) private var manager
    
    var sortedPlayers: [Player] {
        manager.players.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        List(sortedPlayers) { player in
            NavigationLink(destination: AdminPlayerRoundsView(player: player)) {
                HStack {
                    Text(player.name)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Select Player")
    }
}

struct AdminPlayerRoundsView: View {
    let player: Player
    @Environment(TournamentManager.self) private var manager
    
    var playerScore: Score? {
        manager.scores.first { $0.playerId == player.id }
    }
    
    var body: some View {
        List {
            if let score = playerScore {
                ForEach(score.rounds, id: \.roundNumber) { round in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Round \(round.roundNumber)")
                                .font(.headline)
                            Text("\(round.totalGross) strokes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if round.isAttested {
                            Button {
                                manager.unlockRound(playerId: player.id, roundNumber: round.roundNumber)
                            } label: {
                                Text("Unlock")
                                    .fontWeight(.bold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.open.fill")
                                Text("Open")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No scores found for this player.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("\(player.name)'s Rounds")
    }
}

// MARK: - Admin CTP Views

struct AdminCTPListView: View {
    @Environment(TournamentManager.self) private var manager
    
    var body: some View {
        List {
            ForEach(manager.ctpContests.sorted(by: { $0.round < $1.round })) { contest in
                AdminCTPSectionView(contest: contest)
            }
        }
        .navigationTitle("CTP Adjudicator")
    }
}

struct AdminCTPSectionView: View {
    let contest: CTPContest
    @Environment(TournamentManager.self) private var manager
    
    // Moved the complex sorting logic OUT of the view body
    var sortedEntries: [CTPEntry] {
        contest.entries.sorted {
            ($0.feet * 12 + $0.inches) < ($1.feet * 12 + $1.inches)
        }
    }
    
    var body: some View {
        Section {
            if contest.entries.isEmpty {
                Text("No measurements submitted yet.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(sortedEntries) { entry in
                    AdminCTPEntryRow(contest: contest, entry: entry)
                }
            }
            
            if contest.isClosed {
                Button(role: .destructive) {
                    manager.adjudicateCTP(contestId: contest.id, winningEntryId: nil)
                } label: {
                    HStack {
                        Spacer()
                        Text("Reopen Contest")
                        Spacer()
                    }
                }
            }
        } header: {
            HStack {
                Text("Round \(contest.round) • Hole \(contest.hole)")
                Spacer()
                if contest.isClosed {
                    Text("CLOSED")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

struct AdminCTPEntryRow: View {
    let contest: CTPContest
    let entry: CTPEntry
    @Environment(TournamentManager.self) private var manager
    
    // Moved the lookup logic OUT of the view body
    var player: Player? {
        manager.players.first(where: { $0.id == entry.playerId })
    }
    
    var isWinner: Bool {
        contest.winningEntryId == entry.id
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(player?.name ?? "Unknown")
                    .font(.headline)
                Text("\(entry.feet)' \(entry.inches)\"")
                    .font(.subheadline)
                    .foregroundStyle(isWinner ? Color("DudeCupGreen") : .primary)
            }
            
            Spacer()
            
            if contest.isClosed {
                if isWinner {
                    Label("Winner", systemImage: "crown.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.yellow)
                }
            } else {
                Button {
                    manager.adjudicateCTP(contestId: contest.id, winningEntryId: entry.id)
                } label: {
                    Text("Crown Winner")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("DudeCupGreen"))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - The Ledger View

struct LedgerView: View {
    @Environment(TournamentManager.self) private var manager
    @Environment(AuthManager.self) private var authManager

    private let benGold  = Color(red: 0.82, green: 0.68, blue: 0.30)
    private let roseGold = Color(red: 0.82, green: 0.58, blue: 0.54)

    struct PlayerLedger: Identifiable {
        let id: UUID
        let player: Player
        let amountIn: Double     // total paid into bets
        let amountWon: Double    // confirmed winnings (resolved challenges + won skins)
        let pendingValue: Double // potential still in play
        var net: Double { amountWon - amountIn }
        var tier: Tier { net > 0 ? .up : net < 0 ? .down : .even }

        enum Tier {
            case up, even, down
            var label: String {
                switch self { case .up: return "GETTING PAID"; case .even: return "BREAK EVEN"; case .down: return "DEAD MONEY" }
            }
            var color: Color {
                switch self { case .up: return Color(red: 0.25, green: 0.75, blue: 0.45); case .even: return Color(red: 0.85, green: 0.72, blue: 0.25); case .down: return Color(red: 0.85, green: 0.30, blue: 0.30) }
            }
            var icon: String {
                switch self { case .up: return "arrow.up.right"; case .even: return "minus"; case .down: return "arrow.down.right" }
            }
            var tagline: String {
                switch self {
                case .up:   return "In the money"
                case .even: return "Zero sum game"
                case .down: return "Bleeding chips"
                }
            }
        }
    }

    var ledger: [PlayerLedger] {
        manager.players.map { player in
            // What they've paid into bets
            let betAmountIn = manager.betEntries
                .filter { $0.playerId == player.id && $0.status == .paid }
                .reduce(0.0) { sum, entry in
                    sum + (manager.bets.first(where: { $0.id == entry.betId })?.amount ?? 0)
                }

            // Skins bought in
            let skinsBet = manager.bets.first(where: { $0.type == .skins })
            let skinsIn = skinsBet.map { b in
                Double((1...4).filter { manager.isEnteredSkins(playerId: player.id, round: $0) }.count) * b.amount
            } ?? 0

            let amountIn = betAmountIn + skinsIn

            // Confirmed wins from resolved challenges
            let challengeWon = manager.challenges
                .filter { $0.status == .resolved && $0.winnerId == player.id }
                .reduce(0.0) { $0 + $1.amount * 2 }

            // Pending: active/pending challenge stakes they could win
            let pendingValue = manager.challenges
                .filter { ($0.status == .active || $0.status == .pending) && ($0.challengerId == player.id || $0.challengedId == player.id) }
                .reduce(0.0) { $0 + $1.amount * 2 }

            return PlayerLedger(
                id: player.id,
                player: player,
                amountIn: amountIn,
                amountWon: challengeWon,
                pendingValue: pendingValue
            )
        }
        .sorted { a, b in
            // Sort: biggest net first, ties broken by amount in
            if a.net != b.net { return a.net > b.net }
            return a.amountIn > b.amountIn
        }
    }

    var totalInPlay: Double {
        manager.bets.reduce(0.0) { sum, bet in
            sum + bet.amount * Double(manager.betEntries.filter { $0.betId == bet.id && $0.status == .paid }.count)
        }
        + manager.challenges.filter { $0.status == .active || $0.status == .pending }
            .reduce(0.0) { $0 + $1.amount * 2 }
    }

    var upCount: Int  { ledger.filter { $0.tier == .up }.count }
    var downCount: Int { ledger.filter { $0.tier == .down }.count }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    ledgerHero
                    tierSection(.up)
                    tierSection(.even)
                    tierSection(.down)
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("THE LEDGER")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // ── Hero ──────────────────────────────────────────────────────────────

    var ledgerHero: some View {
        ZStack {
            Color.black
            // Subtle split glow — green left, red right
            HStack(spacing: 0) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red:0.25,green:0.75,blue:0.45).opacity(0.10), Color.clear],
                                        startPoint: .leading, endPoint: .trailing))
                Rectangle()
                    .fill(LinearGradient(colors: [Color.clear, Color(red:0.85,green:0.30,blue:0.30).opacity(0.10)],
                                        startPoint: .leading, endPoint: .trailing))
            }
            .frame(maxWidth: .infinity).frame(height: 160)

            VStack(spacing: 4) {
                Text("TOTAL ACTION").font(.system(size: 9, weight: .heavy)).tracking(5)
                    .foregroundStyle(benGold).padding(.top, 28)
                DCCurrencyText(amount: totalInPlay, size: 100)
                    .padding(.vertical, 4)

                // Mini ticker row
                HStack(spacing: 20) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color(red:0.25,green:0.75,blue:0.45))
                        Text("\(upCount) GETTING PAID")
                            .font(.system(size: 9, weight: .heavy)).tracking(2)
                            .foregroundStyle(Color(red:0.25,green:0.75,blue:0.45))
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color(red:0.85,green:0.30,blue:0.30))
                        Text("\(downCount) DEAD MONEY")
                            .font(.system(size: 9, weight: .heavy)).tracking(2)
                            .foregroundStyle(Color(red:0.85,green:0.30,blue:0.30))
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    // ── Tier section ──────────────────────────────────────────────────────

    @ViewBuilder
    func tierSection(_ tier: PlayerLedger.Tier) -> some View {
        let rows = ledger.filter { $0.tier == tier }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                HStack(spacing: 8) {
                    Circle().fill(tier.color).frame(width: 7, height: 7)
                    Text(tier.label)
                        .font(.system(size: 9, weight: .heavy)).tracking(4)
                        .foregroundStyle(tier.color)
                    Spacer()
                    Text(tier.tagline)
                        .font(.system(size: 9, weight: .heavy)).tracking(2)
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 10)

                // Player rows
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        ledgerRow(row)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    func ledgerRow(_ row: PlayerLedger) -> some View {
        let isMe = authManager.currentPlayer?.id == row.player.id
        let netSign = row.net >= 0 ? "+" : ""

        return HStack(spacing: 14) {
            // Trend icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(row.tier.color.opacity(0.10))
                    .frame(width: 42, height: 42)
                Image(systemName: row.tier.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(row.tier.color)
            }

            // Name + in/pending
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.player.firstName)
                        .font(.system(size: 15, weight: .heavy)).fontWidth(.compressed)
                        .foregroundStyle(.white)
                    if isMe {
                        Text("YOU")
                            .font(.system(size: 8, weight: .heavy)).tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(red: 0.82, green: 0.68, blue: 0.30))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 10) {
                    Text("IN $\(Int(row.amountIn))")
                        .font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundStyle(.white.opacity(0.25))
                    if row.pendingValue > 0 {
                        Text("↗ $\(Int(row.pendingValue)) LIVE")
                            .font(.system(size: 9, weight: .heavy)).tracking(1)
                            .foregroundStyle(Color(red:0.25,green:0.75,blue:0.45).opacity(0.6))
                    }
                }
            }

            Spacer()

            // Net P&L — the hero number
            Text("\(netSign)$\(abs(Int(row.net)))")
                .font(.system(size: 26, weight: .black)).fontWidth(.compressed)
                .foregroundStyle(row.tier.color)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isMe ? row.tier.color.opacity(0.35) : row.tier.color.opacity(0.08),
                            lineWidth: isMe ? 1.5 : 1
                        )
                )
        )
    }
}

// MARK: - Bookmaker Ticker

