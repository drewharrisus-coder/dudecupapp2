//
//  AuthManager.swift
//  The Rug
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import LocalAuthentication
import Security

@Observable
class AuthManager {
    static let shared = AuthManager()

    var isAuthenticated = false
    var currentPlayer: Player?
    var verificationID: String?
    var isLoading = false
    var errorMessage: String?

    private let db = Firestore.firestore()
    private let keychainService = "com.dudecup.therug"
    private let keychainAccount = "userPhone"

    private init() {
        checkStoredCredentials()
    }

    // MARK: - Stored Credentials Check

    func checkStoredCredentials() {
        guard let storedPhone = getStoredPhoneNumber() else {
            isAuthenticated = false
            return
        }
        authenticateWithBiometrics(phoneNumber: storedPhone)
    }

    // MARK: - Biometric Authentication

    func authenticateWithBiometrics(phoneNumber: String) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            silentSignIn(phoneNumber: phoneNumber)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                localizedReason: "Sign in to The Dude Cup") { [weak self] success, _ in
            DispatchQueue.main.async {
                if success { self?.silentSignIn(phoneNumber: phoneNumber) }
                else { self?.isAuthenticated = false; self?.errorMessage = "Biometric authentication failed" }
            }
        }
    }

    // MARK: - Silent Sign In

    private func silentSignIn(phoneNumber: String) {
        Task {
            do {
                if Auth.auth().currentUser == nil {
                    try await Auth.auth().signInAnonymously()
                }
                await linkPlayerProfile(phoneNumber: phoneNumber)
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Phone Authentication

    func sendVerificationCode(phoneNumber: String) async throws {
        await MainActor.run { isLoading = true; errorMessage = nil }
        let formatted = phoneNumber.hasPrefix("+") ? phoneNumber : "+1\(phoneNumber.filter { $0.isNumber })"
        do {
            let vid = try await PhoneAuthProvider.provider().verifyPhoneNumber(formatted, uiDelegate: nil)
            await MainActor.run { self.verificationID = vid; self.isLoading = false }
        } catch {
            await MainActor.run { self.isLoading = false; self.errorMessage = "Failed to send code: \(error.localizedDescription)" }
            throw error
        }
    }

    func verifyCode(code: String, phoneNumber: String) async throws {
        guard let vid = verificationID else {
            throw NSError(domain: "AuthManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No verification ID"])
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: vid, verificationCode: code)
            try await Auth.auth().signIn(with: credential)
            storePhoneNumber(phoneNumber)
            await linkPlayerProfile(phoneNumber: phoneNumber)
            await MainActor.run { self.isLoading = false }
        } catch {
            await MainActor.run { self.isLoading = false; self.errorMessage = "Verification failed: \(error.localizedDescription)" }
            throw error
        }
    }

    // MARK: - Player Profile Linking
    // Primary: query Firestore players collection by phone number.
    // Fallback: match against TournamentManager in-memory list (handles mock data + race condition).

    func retryPlayerLinkIfNeeded(players: [Player]) {
        guard currentPlayer == nil, let storedPhone = getStoredPhoneNumber() else { return }
        let clean = storedPhone.filter { $0.isNumber }
        if let player = players.first(where: {
            let pp = $0.phone.filter { $0.isNumber }
            return pp.hasSuffix(clean) || clean.hasSuffix(pp)
        }) {
            DispatchQueue.main.async {
                self.currentPlayer = player
                self.isAuthenticated = true
                print("✅ Retry link succeeded: \(player.name)")
            }
        }
    }

    private func linkPlayerProfile(phoneNumber: String) async {
        let clean = phoneNumber.filter { $0.isNumber }

        // 1. Try Firestore first — real registered players
        do {
            let snapshot = try await db.collection("players")
                .whereField("phoneCleaned", isEqualTo: clean)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first {
                let player = playerFromFirestore(doc: doc)
                await MainActor.run {
                    self.currentPlayer = player
                    self.isAuthenticated = true
                    print("✅ Authenticated from Firestore: \(player.name)")
                }
                return
            }
        } catch {
            print("⚠️ Firestore player lookup failed: \(error) — falling back to local list")
        }

        // 2. Fallback: match against in-memory list (mock data or already-loaded players)
        let players = TournamentManager.shared.players
        if let player = players.first(where: {
            let pp = $0.phone.filter { $0.isNumber }
            return pp.hasSuffix(clean) || clean.hasSuffix(pp)
        }) {
            await MainActor.run {
                self.currentPlayer = player
                self.isAuthenticated = true
                print("✅ Authenticated from local list: \(player.name)")
            }
        } else {
            await MainActor.run {
                self.errorMessage = "No player found with that number. Make sure you've registered at register.dudecupgolf.com"
                self.isAuthenticated = false
            }
        }
    }

    // MARK: - Firestore → Player decoder

    private func playerFromFirestore(doc: QueryDocumentSnapshot) -> Player {
        let d = doc.data()
        var p = Player(
            id:         UUID(uuidString: doc.documentID) ?? UUID(),
            name:       d["name"]       as? String ?? "Unknown",
            handicap:   d["handicap"]   as? Int    ?? 18,
            team:       d["team"]       as? String ?? "",
            avatarName: d["avatarName"] as? String ?? "person.fill",
            hometown:   d["hometown"]   as? String ?? "",
            phone:      d["phone"]      as? String ?? "",
            email:      d["email"]      as? String ?? ""
        )
        p.nickname      = d["nickname"]      as? String
        p.handicapIndex = d["handicapIndex"] as? Double
        p.ghinNumber    = d["ghinNumber"]    as? String
        p.photoURL      = d["photoURL"]      as? String
        p.venmoHandle   = d["venmoHandle"]   as? String
        p.aboutMe       = d["aboutMe"]       as? String
        p.debutYear     = d["debutYear"]     as? Int
        p.tshirtSize    = d["tshirtSize"]    as? String
        p.registeredAt  = (d["registeredAt"] as? Timestamp)?.dateValue()
        p.isConfirmed   = d["isConfirmed"]   as? Bool ?? false
        return p
    }

    // MARK: - Keychain

    private func storePhoneNumber(_ phoneNumber: String) {
        let data = Data(phoneNumber.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: keychainService,
                                     kSecAttrAccount as String: keychainAccount,
                                     kSecValueData as String: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getStoredPhoneNumber() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: keychainService,
                                     kSecAttrAccount as String: keychainAccount,
                                     kSecReturnData as String: true,
                                     kSecMatchLimit as String: kSecMatchLimitOne]
        var ref: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteStoredPhoneNumber() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: keychainService,
                                     kSecAttrAccount as String: keychainAccount]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            deleteStoredPhoneNumber()
            isAuthenticated = false
            currentPlayer = nil
            print("✅ Signed out")
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
}
