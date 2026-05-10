// ioscrmapp/ioscrmapp/Core/Storage/OnboardingStateStore.swift
import Foundation
import os

/// Persists entry routing state for consumption by downstream journeys.
/// Uses UserDefaults for non-sensitive routing decisions.
final class OnboardingStateStore: Sendable {
    private let defaults: UserDefaults
    private let stateKey = "onboarding.entryRoutingState"
    private let numberSelectionKey = "onboarding.numberSelection"
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
        saveCodable(state, forKey: stateKey, label: "EntryRoutingState")
    }

    /// Save the selected/locked number for downstream plan, order, and activation journeys.
    func save(_ selection: NumberSelection) {
        saveCodable(selection, forKey: numberSelectionKey, label: "NumberSelection")
    }

    /// Load persisted number selection after the short lock succeeds.
    func loadNumberSelection() -> NumberSelection? {
        loadCodable(NumberSelection.self, forKey: numberSelectionKey, label: "NumberSelection")
    }

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String, label: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            logger.error("Failed to encode \(label): \(error.localizedDescription)")
        }
    }

    /// Load persisted entry routing state.
    // IMPROVED: Added error logging for decode failures
    func load() -> EntryRoutingState? {
        loadCodable(EntryRoutingState.self, forKey: stateKey, label: "EntryRoutingState")
    }

    private func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String, label: String) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Failed to decode \(label): \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear persisted state (e.g., after flow completion or reset).
    func clear() {
        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: numberSelectionKey)
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
