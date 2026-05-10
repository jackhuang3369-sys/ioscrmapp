import AVFoundation
import Foundation
import VisionKit

protocol DocumentOCRServicing: Sendable {
    func scanDocument(type: DocumentType) async throws -> ScannedDocument
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument]
    func checkCameraPermission() async -> Bool
    func requestCameraPermission() async -> Bool
}

actor DocumentOCRService: DocumentOCRServicing {
    func scanDocument(type: DocumentType) async throws -> ScannedDocument {
        try await Task.sleep(nanoseconds: 100_000_000)
        return ScannedDocument(
            type: type,
            extractedData: mockExtractedData(for: type),
            scanTimestamp: Date()
        )
    }

    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        var documents: [ScannedDocument] = []
        for type in types {
            documents.append(try await scanDocument(type: type))
        }
        return documents
    }

    func checkCameraPermission() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func mockExtractedData(for type: DocumentType) -> EKYCMetadata {
        switch type {
        case .emiratesID:
            return EKYCMetadata(
                fullName: "Mock Emirates ID User",
                phoneNumber: nil,
                documentType: "Emirates ID",
                documentNumber: "784-1234-5678901-2",
                documentExpiryDate: "2030-12-31"
            )
        case .passport:
            return EKYCMetadata(
                fullName: "Mock Passport User",
                phoneNumber: nil,
                documentType: "Passport",
                documentNumber: "A12345678",
                documentExpiryDate: "2028-06-30"
            )
        }
    }
}
