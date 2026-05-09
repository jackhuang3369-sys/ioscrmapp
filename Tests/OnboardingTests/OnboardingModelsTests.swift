// Tests/OnboardingTests/OnboardingModelsTests.swift
import Foundation
import Testing
@testable import du_App

@Suite("Onboarding Models Tests")
struct OnboardingModelsTests {

    @Test("EntryIntent has onboarding and login cases")
    func entryIntentHasCorrectCases() throws {
        #expect(EntryIntent.onboarding.rawValue == "onboarding")
        #expect(EntryIntent.login.rawValue == "login")
    }

    @Test("EntryIntent is Codable")
    func entryIntentIsCodable() throws {
        let intent = EntryIntent.onboarding
        let encoded = try JSONEncoder().encode(intent)
        let decoded = try JSONDecoder().decode(EntryIntent.self, from: encoded)
        #expect(decoded == intent)
    }

    @Test("EntryIntent is CaseIterable")
    func entryIntentIsCaseIterable() throws {
        #expect(EntryIntent.allCases.count == 2)
        #expect(EntryIntent.allCases.contains(.onboarding))
        #expect(EntryIntent.allCases.contains(.login))
    }

    @Test("AcquisitionPath has new_number and port_in cases")
    func acquisitionPathHasCorrectCases() throws {
        #expect(AcquisitionPath.newNumber.rawValue == "new_number")
        #expect(AcquisitionPath.portIn.rawValue == "port_in")
    }

    @Test("AcquisitionPath is Codable")
    func acquisitionPathIsCodable() throws {
        let path = AcquisitionPath.portIn
        let encoded = try JSONEncoder().encode(path)
        let decoded = try JSONDecoder().decode(AcquisitionPath.self, from: encoded)
        #expect(decoded == path)
    }

    @Test("AcquisitionPath cannot be both new_number and port_in")
    func acquisitionPathIsSingleValue() throws {
        let path = AcquisitionPath.newNumber
        #expect(path != .portIn)
    }

    @Test("AcquisitionPath is CaseIterable")
    func acquisitionPathIsCaseIterable() throws {
        #expect(AcquisitionPath.allCases.count == 2)
        #expect(AcquisitionPath.allCases.contains(.newNumber))
        #expect(AcquisitionPath.allCases.contains(.portIn))
    }

    @Test("AuthPath has uaePassLogin case")
    func authPathHasCorrectCases() throws {
        #expect(AuthPath.uaePassLogin.rawValue == "uae_pass_login")
    }

    @Test("AuthPath is Codable")
    func authPathIsCodable() throws {
        let path = AuthPath.uaePassLogin
        let encoded = try JSONEncoder().encode(path)
        let decoded = try JSONDecoder().decode(AuthPath.self, from: encoded)
        #expect(decoded == path)
    }

    @Test("EntryRoutingState creates onboarding state correctly")
    func entryRoutingStateOnboardingFactory() throws {
        let state = EntryRoutingState.onboarding(path: .newNumber)

        #expect(state.entryIntent == .onboarding)
        #expect(state.acquisitionPath == .newNumber)
        #expect(state.authPath == nil)
    }

    @Test("EntryRoutingState creates login state correctly")
    func entryRoutingStateLoginFactory() throws {
        let state = EntryRoutingState.login()

        #expect(state.entryIntent == .login)
        #expect(state.acquisitionPath == nil)
        #expect(state.authPath == .uaePassLogin)
    }

    @Test("EntryRoutingState is Codable")
    func entryRoutingStateIsCodable() throws {
        let original = EntryRoutingState.onboarding(path: .portIn)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntryRoutingState.self, from: encoded)

        #expect(decoded.entryIntent == original.entryIntent)
        #expect(decoded.acquisitionPath == original.acquisitionPath)
        #expect(decoded.authPath == original.authPath)
    }

    @Test("EntryRoutingState is Equatable")
    func entryRoutingStateIsEquatable() throws {
        let state1 = EntryRoutingState.onboarding(path: .newNumber)
        let state2 = EntryRoutingState.onboarding(path: .newNumber)
        let state3 = EntryRoutingState.login()

        #expect(state1 == state2)
        #expect(state1 != state3)
    }

    @Test("EntryRoutingState has createdAt timestamp")
    func entryRoutingStateHasCreatedAt() throws {
        let before = Date()
        let state = EntryRoutingState.login()
        let after = Date()

        #expect(state.createdAt >= before)
        #expect(state.createdAt <= after)
    }

    @Test("EntryRoutingState can be created with custom timestamp")
    func entryRoutingStateCustomTimestamp() throws {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let state = EntryRoutingState(
            entryIntent: .login,
            createdAt: customDate
        )

        #expect(state.createdAt == customDate)
    }
}