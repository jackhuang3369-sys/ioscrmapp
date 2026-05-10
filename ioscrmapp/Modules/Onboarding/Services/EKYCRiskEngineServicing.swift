import Foundation

protocol EKYCRiskEngineServicing: Sendable {
    func assessRisk(request: RiskAssessmentRequest) async throws -> RiskAssessmentResponse
}

actor MockEKYCRiskEngine: EKYCRiskEngineServicing {
    private var simulatedRiskLevel: RiskLevel = .low
    private var simulateRegulatoryMandatory = false

    func assessRisk(request: RiskAssessmentRequest) async throws -> RiskAssessmentResponse {
        try await Task.sleep(nanoseconds: 50_000_000)

        let requirements: EKYCEnhancedRequirements
        if simulateRegulatoryMandatory {
            requirements = EKYCEnhancedRequirements(
                deviceBiometricRequired: true,
                faceLivenessRequired: false,
                documentScanRequired: true,
                documentTypes: [.emiratesID],
                isRegulatoryMandatory: true,
                riskLevel: .critical
            )
        } else {
            switch simulatedRiskLevel {
            case .low:
                requirements = .none
            case .medium:
                requirements = EKYCEnhancedRequirements(
                    deviceBiometricRequired: true,
                    faceLivenessRequired: false,
                    documentScanRequired: false,
                    documentTypes: [],
                    isRegulatoryMandatory: false,
                    riskLevel: .medium
                )
            case .high:
                requirements = EKYCEnhancedRequirements(
                    deviceBiometricRequired: true,
                    faceLivenessRequired: false,
                    documentScanRequired: true,
                    documentTypes: [.emiratesID],
                    isRegulatoryMandatory: false,
                    riskLevel: .high
                )
            case .critical:
                requirements = EKYCEnhancedRequirements(
                    deviceBiometricRequired: true,
                    faceLivenessRequired: false,
                    documentScanRequired: true,
                    documentTypes: [.emiratesID, .passport],
                    isRegulatoryMandatory: true,
                    riskLevel: .critical
                )
            }
        }

        return RiskAssessmentResponse(
            riskLevel: requirements.riskLevel,
            enhancedRequirements: requirements,
            assessmentId: UUID().uuidString,
            assessedAt: Date()
        )
    }

    func setScenario(riskLevel: RiskLevel, regulatoryMandatory: Bool = false) {
        simulatedRiskLevel = riskLevel
        simulateRegulatoryMandatory = regulatoryMandatory
    }
}
