import Foundation

protocol AuthServicing: Sendable {
    func loginWithPassword(phone: String, password: String) async throws -> UserSession
    func sendOTP(to phone: String) async throws -> OTPSendResult
    func loginWithOTP(phone: String, otp: String) async throws -> UserSession
}

actor MockAuthService: AuthServicing {
    private struct OTPRecord {
        let code: String
        let resendAvailableAt: Date
        let expiresAt: Date
    }

    private let validPassword = AuthValidator.demoPassword
    private let validOTP = AuthValidator.demoOTP
    private let cooldownSeconds = 60
    private let expirySeconds = 300
    private let lockThreshold = 5
    private let lockDurationSeconds = 15 * 60

    private var otpByPhone: [String: OTPRecord] = [:]
    private var failuresByPhone: [String: Int] = [:]
    private var lockUntilByPhone: [String: Date] = [:]

    func loginWithPassword(phone: String, password: String) async throws -> UserSession {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard password == validPassword else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        return demoSession(phone: phone)
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = otpByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up))))
        }

        let now = Date()
        let record = OTPRecord(
            code: validOTP,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
        otpByPhone[normalizedPhone] = record

        return OTPSendResult(
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: record.expiresAt,
            demoCode: record.code
        )
    }

    func loginWithOTP(phone: String, otp: String) async throws -> UserSession {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let record = otpByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }

        guard record.expiresAt > Date() else {
            otpByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }

        guard otp == record.code else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        otpByPhone.removeValue(forKey: normalizedPhone)
        return demoSession(phone: phone)
    }

    private func demoSession(phone: String) -> UserSession {
        UserSession(
            displayName: "Ahmed Mohammed",
            phoneNumber: AuthValidator.formattedPhone(phone),
            greeting: "Good Morning",
            balanceText: "128.50 AED"
        )
    }

    private func checkLock(for phone: String) throws {
        if let lockUntil = lockUntilByPhone[phone], lockUntil > Date() {
            throw AuthError.accountLocked(until: lockUntil)
        }
        if let lockUntil = lockUntilByPhone[phone], lockUntil <= Date() {
            lockUntilByPhone.removeValue(forKey: phone)
            failuresByPhone[phone] = 0
        }
    }

    private func clearFailures(for phone: String) {
        failuresByPhone[phone] = 0
        lockUntilByPhone.removeValue(forKey: phone)
    }

    private func registerFailure(for phone: String) -> AuthError {
        let currentFailures = (failuresByPhone[phone] ?? 0) + 1
        failuresByPhone[phone] = currentFailures

        if currentFailures >= lockThreshold {
            let lockUntil = Date().addingTimeInterval(TimeInterval(lockDurationSeconds))
            lockUntilByPhone[phone] = lockUntil
            return .accountLocked(until: lockUntil)
        }

        return .invalidCredentials(remainingAttempts: lockThreshold - currentFailures)
    }

    private func maybeSimulateNetworkFailure(phone: String) throws {
        if phone.hasSuffix("0000") {
            throw AuthError.networkUnavailable
        }
    }
}
