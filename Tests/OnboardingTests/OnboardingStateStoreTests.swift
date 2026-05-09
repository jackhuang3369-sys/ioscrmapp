// Tests/OnboardingTests/OnboardingStateStoreTests.swift
import Foundation
import Testing
@testable import du_App

@Suite("OnboardingStateStore Tests")
struct OnboardingStateStoreTests {

    @Test("OnboardingStateStore saves and loads EntryRoutingState")
    func storeSavesAndLoadsState() async throws {
        let store = OnboardingStateStore(suiteName: "test.onboarding")
        let state = EntryRoutingState.onboarding(path: .newNumber)

        store.save(state)
        let loaded = store.load()

        #expect(loaded?.entryIntent == .onboarding)
        #expect(loaded?.acquisitionPath == .newNumber)
    }

    @Test("OnboardingStateStore clears state")
    func storeClearsState() async throws {
        let store = OnboardingStateStore(suiteName: "test.onboarding.clear")
        store.save(EntryRoutingState.login())

        store.clear()
        let loaded = store.load()

        #expect(loaded == nil)
    }

    @Test("OnboardingStateStore returns nil when no state saved")
    func storeReturnsNilWhenEmpty() async throws {
        let store = OnboardingStateStore(suiteName: "test.onboarding.empty")
        let loaded = store.load()

        #expect(loaded == nil)
    }

    @Test("OnboardingStateStore hasAcquisitionPath returns correct value")
    func hasAcquisitionPathReturnsCorrectValue() async throws {
        let storeWith = OnboardingStateStore(suiteName: "test.onboarding.hasPath.with")
        storeWith.save(EntryRoutingState.onboarding(path: .newNumber))
        #expect(storeWith.hasAcquisitionPath == true)

        let storeWithout = OnboardingStateStore(suiteName: "test.onboarding.hasPath.without")
        storeWithout.save(EntryRoutingState.login())
        #expect(storeWithout.hasAcquisitionPath == false)
    }

    @Test("OnboardingStateStore acquisitionPath returns persisted path")
    func acquisitionPathReturnsPersistedPath() async throws {
        let store = OnboardingStateStore(suiteName: "test.onboarding.acqPath")
        store.save(EntryRoutingState.onboarding(path: .portIn))

        #expect(store.acquisitionPath == .portIn)
    }

    @Test("OnboardingStateStore acquisitionPath returns nil for login state")
    func acquisitionPathReturnsNilForLoginState() async throws {
        let store = OnboardingStateStore(suiteName: "test.onboarding.acqPath.login")
        store.save(EntryRoutingState.login())

        #expect(store.acquisitionPath == nil)
    }
}