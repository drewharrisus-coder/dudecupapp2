//
//  AuthViews.swift
//  The Rug
//
//  Created for The Dude Cup 2026
//

import SwiftUI

// MARK: - Authentication Gate

struct AuthGateView: View {
    @Environment(AuthManager.self) private var authManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
            } else {
                PhoneNumberView()
            }
        }
    }
}

// MARK: - Phone Number Entry

struct PhoneNumberView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var phoneNumber = ""
    @State private var showingVerification = false
    @FocusState private var isPhoneFocused: Bool
    
    var formattedPhone: String {
        let digits = phoneNumber.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        
        var result = ""
        for (index, char) in digits.prefix(10).enumerated() {
            if index == 0 { result += "(" }
            if index == 3 { result += ") " }
            if index == 6 { result += "-" }
            result.append(char)
        }
        return result
    }
    
    var isValidPhone: Bool {
        phoneNumber.filter { $0.isNumber }.count == 10
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo area
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color("DudeCupGreen").gradient)
                        .frame(width: 100, height: 100)
                        .overlay {
                            Text("⛳️")
                                .font(.system(size: 50))
                        }
                    Text("THE DUDE CUP")
                        .font(.system(size: 28, weight: .black))
                        .tracking(2)
                    Text("2026")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 16) {
                    Text("Enter your phone number")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("We'll send you a verification code")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("(555) 555-5555", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.system(size: 24, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isPhoneFocused)
                        .onChange(of: phoneNumber) { oldValue, newValue in
                            // Auto-format as user types
                            let digits = newValue.filter { $0.isNumber }
                            if digits.count <= 10 {
                                phoneNumber = digits
                            } else {
                                phoneNumber = String(digits.prefix(10))
                            }
                        }
                    
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        Task {
                            do {
                                try await authManager.sendVerificationCode(phoneNumber: phoneNumber)
                                showingVerification = true
                            } catch {
                                // Error already set in authManager
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("Send Code")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidPhone && !authManager.isLoading ? Color("DudeCupGreen") : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isValidPhone || authManager.isLoading)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("By signing in, you agree to participate\nin The Dude Cup 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // ⚠️ REMOVE BEFORE TOURNAMENT — dev login bypass
                    VStack(spacing: 6) {
                        Text("DEV LOGIN").font(.system(size: 9, weight: .heavy)).tracking(3).foregroundStyle(.orange.opacity(0.6))
                        ForEach(TournamentManager.shared.players.prefix(6)) { player in
                            Button {
                                authManager.currentPlayer = player
                                authManager.isAuthenticated = true
                            } label: {
                                Text(player.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .navigationDestination(isPresented: $showingVerification) {
                VerificationCodeView(phoneNumber: phoneNumber)
            }
            .onAppear {
                isPhoneFocused = true
            }
        }
    }
}

// MARK: - Verification Code Entry

struct VerificationCodeView: View {
    @Environment(AuthManager.self) private var authManager
    let phoneNumber: String
    
    @State private var code = ""
    @FocusState private var isCodeFocused: Bool
    
    var isValidCode: Bool {
        code.count == 6
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color("DudeCupGreen"))
                
                Text("Enter verification code")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("We sent a code to \(formatPhone(phoneNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isCodeFocused)
                    .onChange(of: code) { oldValue, newValue in
                        // Limit to 6 digits
                        let digits = newValue.filter { $0.isNumber }
                        if digits.count <= 6 {
                            code = digits
                        } else {
                            code = String(digits.prefix(6))
                        }
                    }
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    Task {
                        do {
                            try await authManager.verifyCode(code: code, phoneNumber: phoneNumber)
                        } catch {
                            // Error already set in authManager
                        }
                    }
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Verify")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidCode && !authManager.isLoading ? Color("DudeCupGreen") : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValidCode || authManager.isLoading)
                
                Button {
                    Task {
                        do {
                            try await authManager.sendVerificationCode(phoneNumber: phoneNumber)
                        } catch {
                            // Error already set
                        }
                    }
                } label: {
                    Text("Resend code")
                        .font(.subheadline)
                        .foregroundStyle(Color("DudeCupGreen"))
                }
                .disabled(authManager.isLoading)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isCodeFocused = true
        }
    }
    
    func formatPhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count == 10 else { return phone }
        
        let areaCode = digits.prefix(3)
        let middle = digits.dropFirst(3).prefix(3)
        let last = digits.dropFirst(6)
        
        return "(\(areaCode)) \(middle)-\(last)"
    }
}

// MARK: - Preview

#Preview {
    PhoneNumberView()
        .environment(AuthManager.shared)
}
