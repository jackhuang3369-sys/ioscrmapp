// ioscrmapp/ioscrmapp/Core/Storage/OnboardingStateStore.swift
import Foundation

/// Persists entry routing state for consumption by downstream journeys.
/// Uses UserDefaults for non-sensitive routing decisions.
final class OnboardingStateStore: Sendable {
    private let defaults: UserDefaults
    private let stateKey = "onboarding.entryRoutingState"

    init(suiteName: String? = nil) {
        self.defaults = suiteName != nil
            ? UserDefaults(suiteName: suiteName)!
            : .standard
    }

    /// Save entry routing state for downstream consumption.
    func save(_ state: EntryRoutingState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        defaults.set(data, forKey: stateKey)
    }

    /// Load persisted entry routing state.
    func load() -> EntryRoutingState? {
        guard let data = defaults.data(forKey: stateKey) else {
            return nil
        }
        return try? JSONDecoder().decode(EntryRoutingState.self, from: data)
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