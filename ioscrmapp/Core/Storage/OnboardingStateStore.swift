// ioscrmapp/ioscrmapp/Core/Storage/OnboardingStateStore.swift
import Foundation
import os

/// Persists entry routing state for consumption by downstream journeys.
/// Uses UserDefaults for non-sensitive routing decisions.
final class OnboardingStateStore: Sendable {
    private let defaults: UserDefaults
    private let stateKey = "onboarding.entryRoutingState"
    // ADDED: Logger for tracking encode/decode failures
    private let logger = Logger(subsystem: "com.crmapp.onboarding", category: "OnboardingStateStore")

    // FIXED: Use safe unwrapping instead of force unwrap to prevent potential crashes
    // when UserDefaults suite initialization fails
    init(suiteName: String? = nil) {
        if let suiteName {
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                preconditionFailure("Failed to create UserDefaults with suite: \(suiteName)")
            }
            self.defaults = defaults
        } else {
            self.defaults = .standard
        }
    }

    /// Save entry routing state for downstream consumption.
    // IMPROVED: Added error logging for encode failures
    func save(_ state: EntryRoutingState) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: stateKey)
        } catch {
            logger.error("Failed to encode EntryRoutingState: \(error.localizedDescription)")
        }
    }

    /// Load persisted entry routing state.
    // IMPROVED: Added error logging for decode failures
    func load() -> EntryRoutingState? {
        guard let data = defaults.data(forKey: stateKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(EntryRoutingState.self, from: data)
        } catch {
            logger.error("Failed to decode EntryRoutingState: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear persisted state (e.g., after flow completion or reset).
    func clear() {
        defaults.removeObject(forKey: stateKey)
    }

    /// Check if acquisition path has been selected.
    var hasAcquisitionPath: Bool {
        load()?.acquisitionPath != nil
    }

    /// Get the persisted acquisition path for downstream journey routing.
    var acquisitionPath: AcquisitionPath? {
        load()?.acquisitionPath
    }
}