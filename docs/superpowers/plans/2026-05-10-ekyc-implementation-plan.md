# eKYC Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 iOS Onboarding 流程中实现可演示的 eKYC 页面与状态流，支持 UAE Pass 主认证、风险评估、Device Biometrics 增强认证、Document OCR 降级/增强路径，并能顺畅进入 Personalization。

**Architecture:** 方案基于现有 SwiftUI + MVVM 结构，在 `Modules/Onboarding` 下增加 eKYC 的模型、服务、ViewModel 和页面；通过协议注入复用现有 `UAEPassServicing`，新增 `UAEPassOAuthHandling`、设备上下文加密器、风险引擎 Mock 和本机能力服务。状态机使用 `EKYCViewState` + `EKYCFlowContext` 单一承载跨步骤上下文，避免 ViewModel 私有 pending 状态。

**Tech Stack:** SwiftUI, Swift Testing, LocalAuthentication, VisionKit, XcodeProj Ruby 脚本, existing `RegistrationRequestEncryptor`, existing `UAEPassServicing`

---

## File Structure

### Create
- `ioscrmapp/Modules/Onboarding/Models/EKYCModels.swift` — eKYC 方法、状态机、风险请求/响应、结果模型、错误模型
- `ioscrmapp/Modules/Onboarding/Services/EKYCServicing.swift` — eKYC 业务服务协议与提交响应模型
- `ioscrmapp/Modules/Onboarding/Services/EKYCRiskEngineServicing.swift` — 风险评估协议与 Mock 风险引擎
- `ioscrmapp/Modules/Onboarding/Services/EKYCDeviceContextEncryptor.swift` — 设备上下文加密实现
- `ioscrmapp/Modules/Onboarding/Services/EKYCService.swift` — eKYC 服务实现
- `ioscrmapp/Modules/Onboarding/ViewModels/EKYCViewModel.swift` — eKYC 流程状态管理
- `ioscrmapp/Modules/Onboarding/Views/EKYCView.swift` — eKYC 主页面
- `ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift` — eKYC UI 子组件
- `ioscrmapp/Services/DeviceBiometricServicing.swift` — Device Biometrics 协议与实现
- `ioscrmapp/Services/DocumentOCRServicing.swift` — Document OCR 协议与实现
- `ioscrmapp/Services/UAEPass/UAEPassOAuthHandling.swift` — UAE Pass OAuth 协议与实现骨架
- `Tests/OnboardingTests/EKYCModelsTests.swift` — eKYC 模型测试
- `Tests/OnboardingTests/EKYCViewModelTests.swift` — eKYC ViewModel 测试
- `Tests/OnboardingTests/EKYCServiceTests.swift` — eKYC Service 测试
- `Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift` — eKYC 测试用 mock 依赖集合
- `ioscrmapp/add_ekyc_files.rb` — 把新文件批量加入 Xcode project 的脚本

### Modify
- `ioscrmapp/Modules/Onboarding/Views/EntryContainerView.swift` — 用 `EKYCView` 替换 placeholder `OnboardingEKYCView`
- `ioscrmapp/Services/AppServices.swift` — 注入 eKYC 需要的运行时依赖构造
- `ioscrmapp/ContentView.swift` — 从上层把 eKYC factories 传入 `EntryContainerView`

### Reference
- `ioscrmapp/Modules/Onboarding/Models/OnboardingModels.swift`
- `ioscrmapp/Modules/Onboarding/ViewModels/EntryViewModel.swift`
- `ioscrmapp/Modules/Onboarding/Views/EntryContainerView.swift`
- `ioscrmapp/Services/RegistrationRequestEncryptor.swift`
- `ioscrmapp/Services/UAEPass/UAEPassModels.swift`
- `ioscrmapp/Services/UAEPass/UAEPassServicing.swift`
- `ioscrmapp/Services/UAEPass/MockUAEPassService.swift`
- `ioscrmapp/Services/UAEPass/RemoteUAEPassService.swift`
- `Tests/OnboardingTests/EntryViewModelTests.swift`
- `Tests/OnboardingTests/OnboardingModelsTests.swift`
- `figma/ekyc.html`

---

### Task 1: 建立 eKYC 模型与模型测试

**Files:**
- Create: `ioscrmapp/Modules/Onboarding/Models/EKYCModels.swift`
- Test: `Tests/OnboardingTests/EKYCModelsTests.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`

- [ ] **Step 1: Write the failing test**

Create `Tests/OnboardingTests/EKYCModelsTests.swift`:

```swift
import Foundation
import Testing
@testable import du_App

@Suite("eKYC Models Tests")
struct EKYCModelsTests {
    @Test("EKYCMethod exposes expected onboarding methods")
    func ekycMethodCases() {
        #expect(EKYCMethod.allCases == [.uaepass, .deviceBiometrics, .documentScan])
        #expect(EKYCMethod.uaepass.title == "UAE Pass")
        #expect(EKYCMethod.deviceBiometrics.icon == "faceid")
        #expect(EKYCMethod.documentScan.subtitle.contains("Emirates ID"))
    }

    @Test("EKYCEnhancedRequirements none disables all enhancements")
    func enhancedRequirementsNone() {
        let requirements = EKYCEnhancedRequirements.none
        #expect(requirements.deviceBiometricRequired == false)
        #expect(requirements.faceLivenessRequired == false)
        #expect(requirements.documentScanRequired == false)
        #expect(requirements.documentTypes.isEmpty)
        #expect(requirements.riskLevel == .low)
    }

    @Test("EKYCFlowContext is Codable")
    func flowContextIsCodable() throws {
        let risk = RiskAssessmentResponse(
            riskLevel: .medium,
            enhancedRequirements: .none,
            assessmentId: "assessment-1",
            assessedAt: Date(timeIntervalSince1970: 10)
        )
        let result = EKYCResult(
            method: .uaepass,
            identityID: "user-1",
            verifiedAt: Date(timeIntervalSince1970: 20),
            metadata: EKYCMetadata(
                fullName: "Test User",
                phoneNumber: "+971501234567",
                documentType: nil,
                documentNumber: nil,
                documentExpiryDate: nil
            ),
            enhancedResults: nil
        )
        let original = EKYCFlowContext(primaryResult: result, riskAssessment: risk)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EKYCFlowContext.self, from: encoded)
        #expect(decoded == original)
    }

    @Test("EncryptedPayload stores encrypted request metadata")
    func encryptedPayloadShape() {
        let payload = EncryptedPayload(
            algorithm: "rsa-pkcs1-v1_5",
            keyId: "registration-public-key-v1",
            ciphertext: "abc123"
        )
        #expect(payload.algorithm == "rsa-pkcs1-v1_5")
        #expect(payload.keyId == "registration-public-key-v1")
        #expect(payload.ciphertext == "abc123")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCModelsTests
```

Expected: FAIL with errors like `cannot find 'EKYCMethod' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Modules/Onboarding/Models/EKYCModels.swift`:

```swift
import Foundation

enum EKYCMethod: String, CaseIterable, Identifiable, Sendable, Codable {
    case uaepass = "UAE Pass"
    case deviceBiometrics = "Device Biometrics"
    case documentScan = "Document Scan"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .uaepass:
            return "checkmark.shield.fill"
        case .deviceBiometrics:
            return "faceid"
        case .documentScan:
            return "person.text.rectangle"
        }
    }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .uaepass:
            return "Fast verification for UAE mobile onboarding."
        case .deviceBiometrics:
            return "Confirm the current device holder with Face ID or Touch ID."
        case .documentScan:
            return "Scan Emirates ID or Passport for manual processing."
        }
    }
}

enum EKYCMethodStatus: Equatable, Sendable {
    case ready
    case comingSoon
    case unavailable(reason: String)
}

enum EKYCPermission: String, Equatable, Sendable, Codable {
    case camera
    case biometrics
    case uaepassApp
}

enum RiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

enum DocumentType: String, Codable, CaseIterable, Sendable {
    case emiratesID = "Emirates ID"
    case passport = "Passport"
}

struct EKYCEnhancedRequirements: Equatable, Sendable, Codable {
    let deviceBiometricRequired: Bool
    let faceLivenessRequired: Bool
    let documentScanRequired: Bool
    let documentTypes: [DocumentType]
    let isRegulatoryMandatory: Bool
    let riskLevel: RiskLevel

    static let none = EKYCEnhancedRequirements(
        deviceBiometricRequired: false,
        faceLivenessRequired: false,
        documentScanRequired: false,
        documentTypes: [],
        isRegulatoryMandatory: false,
        riskLevel: .low
    )
}

struct EKYCMetadata: Equatable, Sendable, Codable {
    let fullName: String?
    let phoneNumber: String?
    let documentType: String?
    let documentNumber: String?
    let documentExpiryDate: String?
}

struct ScannedDocument: Equatable, Sendable, Codable {
    let type: DocumentType
    let extractedData: EKYCMetadata
    let scanTimestamp: Date
}

struct EKYCEnhancedResults: Equatable, Sendable, Codable {
    let deviceBiometricPassed: Bool
    let faceLivenessPassed: Bool
    let documentScanPassed: Bool
    let scannedDocuments: [ScannedDocument]
}

struct EKYCResult: Equatable, Sendable, Codable {
    let method: EKYCMethod
    let identityID: String
    let verifiedAt: Date
    let metadata: EKYCMetadata?
    let enhancedResults: EKYCEnhancedResults?
}

struct EncryptedPayload: Sendable, Codable, Equatable {
    let algorithm: String
    let keyId: String?
    let ciphertext: String
}

struct DeviceContext: Sendable, Codable, Equatable {
    let deviceId: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
}

struct RiskAssessmentRequest: Sendable, Codable, Equatable {
    let primaryVerificationResult: EKYCResult
    let encryptedDeviceContext: EncryptedPayload
    let networkInfo: NetworkInfo
    let businessScenario: BusinessScenario

    struct NetworkInfo: Sendable, Codable, Equatable {
        let connectionType: String
        let carrierName: String?
    }

    enum BusinessScenario: String, Sendable, Codable {
        case newESIMActivation
        case portIn
        case simReplacement
        case highValueTransaction
    }
}

struct RiskAssessmentResponse: Sendable, Codable, Equatable {
    let riskLevel: RiskLevel
    let enhancedRequirements: EKYCEnhancedRequirements
    let assessmentId: String
    let assessedAt: Date
}

struct EKYCFlowContext: Equatable, Sendable, Codable {
    let primaryResult: EKYCResult
    let riskAssessment: RiskAssessmentResponse
}

enum EKYCError: Error, Equatable, LocalizedError {
    case uaepassFailed(reason: String)
    case deviceBiometricFailed(reason: String)
    case faceLivenessFailed(reason: String)
    case documentScanFailed(reason: String)
    case riskAssessmentFailed(reason: String)
    case networkUnavailable
    case permissionDenied(permission: String)
    case timeout
    case userCancelled
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case let .uaepassFailed(reason):
            return "UAE Pass verification failed: \(reason)"
        case let .deviceBiometricFailed(reason):
            return "Device biometric verification failed: \(reason)"
        case let .faceLivenessFailed(reason):
            return "Face liveness verification failed: \(reason)"
        case let .documentScanFailed(reason):
            return "Document scan failed: \(reason)"
        case let .riskAssessmentFailed(reason):
            return "Risk assessment failed: \(reason)"
        case .networkUnavailable:
            return "Network unavailable"
        case let .permissionDenied(permission):
            return "Permission denied: \(permission)"
        case .timeout:
            return "Verification timeout"
        case .userCancelled:
            return "User cancelled verification"
        case let .unknown(message):
            return message
        }
    }
}

enum EKYCViewState: Equatable {
    case idle
    case preparing(method: EKYCMethod, permission: EKYCPermission?)
    case verifying(method: EKYCMethod)
    case assessing(primaryResult: EKYCResult)
    case enhancedRequired(context: EKYCFlowContext)
    case performingEnhanced(context: EKYCFlowContext)
    case submitting(context: EKYCFlowContext, finalResult: EKYCResult)
    case success(result: EKYCResult)
    case failure(error: EKYCError)
}
```

- [ ] **Step 4: Add files to the Xcode project**

Create `ioscrmapp/add_ekyc_files.rb`:

```ruby
#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
base_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp'
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |target| target.name == 'ioscrmapp' }
test_target = project.targets.find { |target| target.name == 'ioscrmappTests' }

def find_or_create_group(project, path_components)
  current_group = project.main_group
  path_components.each do |component|
    child = current_group.children.find { |group| group.display_name == component || group.name == component }
    current_group = if child&.is_a?(Xcodeproj::Project::Object::PBXGroup)
      child
    else
      current_group.new_group(component)
    end
  end
  current_group
end

def add_file(group, target, path)
  return unless File.exist?(path)
  existing = group.files.find { |file| file.path == path || file.real_path.to_s == path }
  file_ref = existing || group.new_file(path)
  target.source_build_phase.add_file_reference(file_ref, true)
end

models_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Models'])
test_group = find_or_create_group(project, ['OnboardingTests'])

add_file(models_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Models/EKYCModels.swift")
add_file(test_group, test_target, "#{base_path}/Tests/OnboardingTests/EKYCModelsTests.swift")

project.save
puts 'Added eKYC files.'
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: `Added eKYC files.`

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCModelsTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/Models/EKYCModels.swift Tests/OnboardingTests/EKYCModelsTests.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: add ekyc domain models"
```

---

### Task 2: 建立 eKYC 协议、Mock 风险引擎与测试依赖

**Files:**
- Create: `ioscrmapp/Modules/Onboarding/Services/EKYCServicing.swift`
- Create: `ioscrmapp/Modules/Onboarding/Services/EKYCRiskEngineServicing.swift`
- Create: `Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift`
- Test: `Tests/OnboardingTests/EKYCServiceTests.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`

- [ ] **Step 1: Write the failing test**

Create `Tests/OnboardingTests/EKYCServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import du_App

@Suite("eKYC Service Protocol Tests")
struct EKYCServiceTests {
    @Test("MockUAEPassOAuthHandler returns deterministic customer info")
    func mockOAuthReturnsCustomer() async throws {
        let handler = MockUAEPassOAuthHandler()
        let customer = try await handler.performOAuth(
            config: UAEPassConfig(
                authorizeURL: "https://example.com/auth",
                clientId: "client-id",
                redirectUri: "duapp://uaepass/callback",
                language: "en",
                environment: "staging",
                scope: "openid profile",
                installedFlowAcrValues: "installed",
                fallbackFlowAcrValues: "fallback",
                state: "state-1"
            )
        )
        #expect(customer.displayName == "Mock User")
        #expect(customer.userID == "mock-user-id")
    }

    @Test("MockEKYCRiskEngine returns none requirements for low risk")
    func mockRiskEngineLowRisk() async throws {
        let engine = MockEKYCRiskEngine()
        await engine.setScenario(riskLevel: .low)
        let response = try await engine.assessRisk(request: makeRiskRequest())
        #expect(response.riskLevel == .low)
        #expect(response.enhancedRequirements == .none)
    }

    @Test("MockDeviceContextEncryptor encodes payload as mock base64 json")
    func mockEncryptorReturnsPayload() async throws {
        let encryptor = MockEKYCDeviceContextEncryptor()
        let payload = try await encryptor.encrypt(
            DeviceContext(deviceId: "device-1", deviceModel: "iPhone", osVersion: "18.0", appVersion: "1.0")
        )
        #expect(payload.algorithm == "mock-base64-json")
        #expect(payload.keyId == "mock")
        #expect(payload.ciphertext.isEmpty == false)
    }

    private func makeRiskRequest() -> RiskAssessmentRequest {
        RiskAssessmentRequest(
            primaryVerificationResult: EKYCResult(
                method: .uaepass,
                identityID: "user-1",
                verifiedAt: Date(timeIntervalSince1970: 1),
                metadata: nil,
                enhancedResults: nil
            ),
            encryptedDeviceContext: EncryptedPayload(
                algorithm: "mock",
                keyId: "mock",
                ciphertext: "ciphertext"
            ),
            networkInfo: RiskAssessmentRequest.NetworkInfo(connectionType: "wifi", carrierName: "du"),
            businessScenario: .newESIMActivation
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: FAIL with `cannot find 'MockUAEPassOAuthHandler' in scope` and `cannot find 'MockEKYCRiskEngine' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Modules/Onboarding/Services/EKYCServicing.swift`:

```swift
import Foundation

protocol EKYCServicing: Sendable {
    func verifyWithUAEPass() async throws -> EKYCResult
    func verifyWithDeviceBiometrics() async throws -> Bool
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument]
    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse
}

struct EKYCSubmitResponse: Equatable, Sendable, Codable {
    let success: Bool
    let verificationId: String
    let nextStep: String
}
```

Create `ioscrmapp/Modules/Onboarding/Services/EKYCRiskEngineServicing.swift`:

```swift
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
```

Create `Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift`:

```swift
import Foundation
@testable import du_App

actor MockUAEPassOAuthHandler: UAEPassOAuthHandling {
    func performOAuth(config: UAEPassConfig) async throws -> CustSubInfo {
        CustSubInfo(
            displayName: "Mock User",
            phoneNumber: "+971501234567",
            greeting: "Good Morning",
            balanceText: "0 AED",
            userID: "mock-user-id",
            serviceNumber: "971501234567",
            subscriberKey: nil
        )
    }
}

actor MockEKYCDeviceContextEncryptor: EKYCDeviceContextEncrypting {
    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload {
        let data = try JSONEncoder().encode(context)
        return EncryptedPayload(
            algorithm: "mock-base64-json",
            keyId: "mock",
            ciphertext: data.base64EncodedString()
        )
    }
}
```

- [ ] **Step 4: Add files to the Xcode project**

Append to `ioscrmapp/add_ekyc_files.rb`:

```ruby
service_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Services'])
mock_group = find_or_create_group(project, ['OnboardingTests', 'Mocks'])

add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCServicing.swift")
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCRiskEngineServicing.swift")
add_file(mock_group, test_target, "#{base_path}/Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift")
add_file(test_group, test_target, "#{base_path}/Tests/OnboardingTests/EKYCServiceTests.swift")
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: script completes without duplicate file errors.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/Services/EKYCServicing.swift ioscrmapp/Modules/Onboarding/Services/EKYCRiskEngineServicing.swift Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift Tests/OnboardingTests/EKYCServiceTests.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: add ekyc service protocols and mocks"
```

---

### Task 3: 建立本机能力协议与真实服务骨架

**Files:**
- Create: `ioscrmapp/Services/DeviceBiometricServicing.swift`
- Create: `ioscrmapp/Services/DocumentOCRServicing.swift`
- Test: `Tests/OnboardingTests/EKYCServiceTests.swift`
- Modify: `Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`

- [ ] **Step 1: Write the failing test**

Append to `Tests/OnboardingTests/EKYCServiceTests.swift`:

```swift
@Test("MockDeviceBiometricService reports notAvailable when configured")
func deviceBiometricMockAvailability() async {
    let service = MockDeviceBiometricService(availability: .notAvailable)
    let availability = await service.checkAvailability()
    #expect(availability == .notAvailable)
}

@Test("MockDocumentOCRService returns a scanned document for each requested type")
func mockDocumentScanReturnsRequestedTypes() async throws {
    let service = MockDocumentOCRService()
    let documents = try await service.scanDocuments(types: [.emiratesID, .passport])
    #expect(documents.count == 2)
    #expect(documents.map(\.type) == [.emiratesID, .passport])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: FAIL with `cannot find 'MockDeviceBiometricService' in scope` and `cannot find 'MockDocumentOCRService' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Services/DeviceBiometricServicing.swift`:

```swift
import Foundation
import LocalAuthentication

protocol DeviceBiometricServicing: Sendable {
    func checkAvailability() async -> DeviceBiometricAvailability
    func authenticate(reason: String) async throws -> Bool
    func supportedBiometricType() -> BiometricType
}

enum DeviceBiometricAvailability: Equatable, Sendable {
    case available
    case notEnrolled
    case notAvailable
    case lockedOut
    case restricted
}

enum BiometricType: Equatable, Sendable {
    case faceID
    case touchID
    case none
}

actor DeviceBiometricService: DeviceBiometricServicing {
    private func makeContext() -> LAContext {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        return context
    }

    func checkAvailability() async -> DeviceBiometricAvailability {
        let context = makeContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    return .notEnrolled
                case LAError.biometryNotAvailable.rawValue:
                    return .notAvailable
                case LAError.biometryLockout.rawValue:
                    return .lockedOut
                case LAError.notInteractive.rawValue:
                    return .restricted
                default:
                    return .notAvailable
                }
            }
            return .notAvailable
        }
        return .available
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = makeContext()
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error {
                    let authError = error as? LAError
                    switch authError {
                    case .userCancel, .userFallback:
                        continuation.resume(throwing: EKYCError.userCancelled)
                    case .biometryNotEnrolled:
                        continuation.resume(throwing: EKYCError.permissionDenied(permission: "Device Biometrics not enrolled"))
                    case .biometryLockout:
                        continuation.resume(throwing: EKYCError.deviceBiometricFailed(reason: "Device Biometrics locked out"))
                    default:
                        continuation.resume(throwing: EKYCError.deviceBiometricFailed(reason: error.localizedDescription))
                    }
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func supportedBiometricType() -> BiometricType {
        let context = makeContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
}
```

Create `ioscrmapp/Services/DocumentOCRServicing.swift`:

```swift
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
```

Append to `Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift`:

```swift
actor MockDeviceBiometricService: DeviceBiometricServicing {
    private let availability: DeviceBiometricAvailability

    init(availability: DeviceBiometricAvailability = .available) {
        self.availability = availability
    }

    func checkAvailability() async -> DeviceBiometricAvailability {
        availability
    }

    func authenticate(reason: String) async throws -> Bool {
        guard availability == .available else {
            throw EKYCError.deviceBiometricFailed(reason: "Device biometrics unavailable")
        }
        return true
    }

    func supportedBiometricType() -> BiometricType {
        availability == .available ? .faceID : .none
    }
}

actor MockDocumentOCRService: DocumentOCRServicing {
    func scanDocument(type: DocumentType) async throws -> ScannedDocument {
        ScannedDocument(
            type: type,
            extractedData: EKYCMetadata(
                fullName: "Mock User",
                phoneNumber: nil,
                documentType: type.rawValue,
                documentNumber: "MOCK-123",
                documentExpiryDate: "2030-01-01"
            ),
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

    func checkCameraPermission() async -> Bool { true }
    func requestCameraPermission() async -> Bool { true }
}
```

- [ ] **Step 4: Add files to the Xcode project**

Append to `ioscrmapp/add_ekyc_files.rb`:

```ruby
root_services_group = find_or_create_group(project, ['ioscrmapp', 'Services'])

add_file(root_services_group, main_target, "#{base_path}/ioscrmapp/Services/DeviceBiometricServicing.swift")
add_file(root_services_group, main_target, "#{base_path}/ioscrmapp/Services/DocumentOCRServicing.swift")
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: file references added without duplicates.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Services/DeviceBiometricServicing.swift ioscrmapp/Services/DocumentOCRServicing.swift Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift Tests/OnboardingTests/EKYCServiceTests.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: add ekyc device capability services"
```

---

### Task 4: 建立 UAE Pass OAuth 抽象与设备上下文加密器

**Files:**
- Create: `ioscrmapp/Services/UAEPass/UAEPassOAuthHandling.swift`
- Create: `ioscrmapp/Modules/Onboarding/Services/EKYCDeviceContextEncryptor.swift`
- Test: `Tests/OnboardingTests/EKYCServiceTests.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`

- [ ] **Step 1: Write the failing test**

Append to `Tests/OnboardingTests/EKYCServiceTests.swift`:

```swift
@Test("EKYCDeviceContextEncryptor returns RSA payload metadata")
func deviceContextEncryptorReturnsRsaMetadata() async throws {
    let encryptor = EKYCDeviceContextEncryptor()
    let payload = try await encryptor.encrypt(
        DeviceContext(deviceId: "device-1", deviceModel: "iPhone 16", osVersion: "18.0", appVersion: "1.0")
    )
    #expect(payload.algorithm == "rsa-pkcs1-v1_5")
    #expect(payload.keyId == "registration-public-key-v1")
    #expect(payload.ciphertext.isEmpty == false)
}

@Test("MockUAEPassOAuthHandler conforms to shared OAuth abstraction")
func oauthHandlerConformsToProtocol() async throws {
    let handler: any UAEPassOAuthHandling = MockUAEPassOAuthHandler()
    let customer = try await handler.performOAuth(
        config: UAEPassConfig(
            authorizeURL: "https://example.com/auth",
            clientId: "client-id",
            redirectUri: "duapp://uaepass/callback",
            language: "en",
            environment: "staging",
            scope: "openid profile",
            installedFlowAcrValues: "installed",
            fallbackFlowAcrValues: "fallback",
            state: "state-2"
        )
    )
    #expect(customer.phoneNumber == "+971501234567")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: FAIL with `cannot find type 'UAEPassOAuthHandling' in scope` and `cannot find 'EKYCDeviceContextEncryptor' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Services/UAEPass/UAEPassOAuthHandling.swift`:

```swift
import Foundation

protocol UAEPassOAuthHandling: Sendable {
    func performOAuth(config: UAEPassConfig) async throws -> CustSubInfo
}

struct OAuthSession: Sendable, Equatable {
    let requestId: String
    let state: String
    let initiatedAt: Date
    let config: UAEPassConfig
}
```

Create `ioscrmapp/Modules/Onboarding/Services/EKYCDeviceContextEncryptor.swift`:

```swift
import Foundation

protocol EKYCDeviceContextEncrypting: Sendable {
    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload
}

struct EKYCDeviceContextEncryptor: EKYCDeviceContextEncrypting {
    private let registrationEncryptor = RegistrationRequestEncryptor()

    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload {
        let data = try JSONEncoder().encode(context)
        let plaintext = String(decoding: data, as: UTF8.self)
        let ciphertext = try await registrationEncryptor.encryptPassword(plaintext)
        return EncryptedPayload(
            algorithm: "rsa-pkcs1-v1_5",
            keyId: "registration-public-key-v1",
            ciphertext: ciphertext
        )
    }
}
```

- [ ] **Step 4: Add files to the Xcode project**

Append to `ioscrmapp/add_ekyc_files.rb`:

```ruby
uae_pass_group = find_or_create_group(project, ['ioscrmapp', 'Services', 'UAEPass'])

add_file(uae_pass_group, main_target, "#{base_path}/ioscrmapp/Services/UAEPass/UAEPassOAuthHandling.swift")
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCDeviceContextEncryptor.swift")
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: script completes successfully.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Services/UAEPass/UAEPassOAuthHandling.swift ioscrmapp/Modules/Onboarding/Services/EKYCDeviceContextEncryptor.swift Tests/OnboardingTests/EKYCServiceTests.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: add ekyc oauth and encryption abstractions"
```

---

### Task 5: 实现 EKYCService 与其业务测试

**Files:**
- Create: `ioscrmapp/Modules/Onboarding/Services/EKYCService.swift`
- Test: `Tests/OnboardingTests/EKYCServiceTests.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`

- [ ] **Step 1: Write the failing test**

Append to `Tests/OnboardingTests/EKYCServiceTests.swift`:

```swift
@Test("EKYCService maps OAuth customer into UAE Pass ekyc result")
func ekycServiceMapsOAuthCustomer() async throws {
    let service = EKYCService(
        uaePassService: MockUAEPassService(),
        oauthHandler: MockUAEPassOAuthHandler(),
        deviceBiometricService: MockDeviceBiometricService(),
        documentOCRService: MockDocumentOCRService()
    )

    let result = try await service.verifyWithUAEPass()
    #expect(result.method == .uaepass)
    #expect(result.identityID == "mock-user-id")
    #expect(result.metadata?.fullName == "Mock User")
}

@Test("EKYCService delegates device biometrics to capability service")
func ekycServiceDelegatesDeviceBiometrics() async throws {
    let service = EKYCService(
        uaePassService: MockUAEPassService(),
        oauthHandler: MockUAEPassOAuthHandler(),
        deviceBiometricService: MockDeviceBiometricService(),
        documentOCRService: MockDocumentOCRService()
    )

    let verified = try await service.verifyWithDeviceBiometrics()
    #expect(verified == true)
}

@Test("EKYCService scans every requested document type")
func ekycServiceScansDocuments() async throws {
    let service = EKYCService(
        uaePassService: MockUAEPassService(),
        oauthHandler: MockUAEPassOAuthHandler(),
        deviceBiometricService: MockDeviceBiometricService(),
        documentOCRService: MockDocumentOCRService()
    )

    let documents = try await service.scanDocuments(types: [.emiratesID, .passport])
    #expect(documents.count == 2)
    #expect(documents.map(\.type) == [.emiratesID, .passport])
}

@Test("EKYCService returns successful submit response")
func ekycServiceSubmitReturnsSuccess() async throws {
    let service = EKYCService(
        uaePassService: MockUAEPassService(),
        oauthHandler: MockUAEPassOAuthHandler(),
        deviceBiometricService: MockDeviceBiometricService(),
        documentOCRService: MockDocumentOCRService()
    )

    let response = try await service.submitVerificationResult(
        EKYCResult(method: .uaepass, identityID: "user-1", verifiedAt: Date(), metadata: nil, enhancedResults: nil),
        assessmentId: "assessment-1"
    )
    #expect(response.success == true)
    #expect(response.nextStep == "personalization")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: FAIL with `cannot find 'EKYCService' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Modules/Onboarding/Services/EKYCService.swift`:

```swift
import Foundation

actor EKYCService: EKYCServicing {
    private let uaePassService: UAEPassServicing
    private let oauthHandler: any UAEPassOAuthHandling
    private let deviceBiometricService: any DeviceBiometricServicing
    private let documentOCRService: any DocumentOCRServicing

    init(
        uaePassService: UAEPassServicing,
        oauthHandler: any UAEPassOAuthHandling,
        deviceBiometricService: any DeviceBiometricServicing,
        documentOCRService: any DocumentOCRServicing
    ) {
        self.uaePassService = uaePassService
        self.oauthHandler = oauthHandler
        self.deviceBiometricService = deviceBiometricService
        self.documentOCRService = documentOCRService
    }

    func verifyWithUAEPass() async throws -> EKYCResult {
        let config = try await uaePassService.getConfig()
        let customer = try await oauthHandler.performOAuth(config: config)
        return EKYCResult(
            method: .uaepass,
            identityID: customer.userID ?? customer.phoneNumber,
            verifiedAt: Date(),
            metadata: EKYCMetadata(
                fullName: customer.displayName,
                phoneNumber: customer.phoneNumber,
                documentType: nil,
                documentNumber: nil,
                documentExpiryDate: nil
            ),
            enhancedResults: nil
        )
    }

    func verifyWithDeviceBiometrics() async throws -> Bool {
        let availability = await deviceBiometricService.checkAvailability()
        switch availability {
        case .available:
            return try await deviceBiometricService.authenticate(reason: "Verify your identity for eSIM activation")
        case .notEnrolled:
            throw EKYCError.permissionDenied(permission: "Device Biometrics not enrolled")
        case .notAvailable:
            throw EKYCError.deviceBiometricFailed(reason: "Device does not support Device Biometrics")
        case .lockedOut:
            throw EKYCError.deviceBiometricFailed(reason: "Device Biometrics is locked out")
        case .restricted:
            throw EKYCError.permissionDenied(permission: "Device Biometrics is restricted")
        }
    }

    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        let hasPermission = await documentOCRService.checkCameraPermission()
        if hasPermission == false {
            let granted = await documentOCRService.requestCameraPermission()
            if granted == false {
                throw EKYCError.permissionDenied(permission: "Camera")
            }
        }
        return try await documentOCRService.scanDocuments(types: types)
    }

    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse {
        try await Task.sleep(nanoseconds: 50_000_000)
        return EKYCSubmitResponse(
            success: true,
            verificationId: UUID().uuidString,
            nextStep: "personalization"
        )
    }
}
```

- [ ] **Step 4: Add files to the Xcode project**

Append to `ioscrmapp/add_ekyc_files.rb`:

```ruby
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCService.swift")
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: script completes successfully.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/Services/EKYCService.swift Tests/OnboardingTests/EKYCServiceTests.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: implement ekyc service"
```

---

### Task 6: 实现 EKYCViewModel 与 ViewModel 测试

**Files:**
- Create: `ioscrmapp/Modules/Onboarding/ViewModels/EKYCViewModel.swift`
- Create: `Tests/OnboardingTests/EKYCViewModelTests.swift`
- Modify: `Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`

- [ ] **Step 1: Write the failing test**

Create `Tests/OnboardingTests/EKYCViewModelTests.swift`:

```swift
import Foundation
import Testing
@testable import du_App

@MainActor
@Suite("eKYC ViewModel Tests")
struct EKYCViewModelTests {
    @Test("ViewModel starts idle with UAE Pass selected")
    func initialState() {
        let viewModel = makeViewModel()
        #expect(viewModel.state == .idle)
        #expect(viewModel.selectedMethod == .uaepass)
    }

    @Test("Selecting method moves state to preparing")
    func selectMethod() {
        let viewModel = makeViewModel()
        viewModel.selectMethod(.documentScan)
        #expect(viewModel.selectedMethod == .documentScan)
        #expect(viewModel.state == .preparing(method: .documentScan, permission: nil))
    }

    @Test("Low risk path submits immediately and completes")
    func lowRiskCompletes() async {
        let riskEngine = MockEKYCRiskEngine()
        await riskEngine.setScenario(riskLevel: .low)

        var completed: EKYCResult?
        let viewModel = makeViewModel(riskEngine: riskEngine, onComplete: { completed = $0 })
        await viewModel.startVerification()

        guard case .success(let result) = viewModel.state else {
            Issue.record("Expected success state")
            return
        }
        #expect(result.method == .uaepass)
        #expect(completed?.identityID == result.identityID)
    }

    @Test("Medium risk stops at enhanced required")
    func mediumRiskStopsAtEnhancedRequired() async {
        let riskEngine = MockEKYCRiskEngine()
        await riskEngine.setScenario(riskLevel: .medium)

        let viewModel = makeViewModel(riskEngine: riskEngine)
        await viewModel.startVerification()

        guard case .enhancedRequired(let context) = viewModel.state else {
            Issue.record("Expected enhancedRequired state")
            return
        }
        #expect(context.riskAssessment.enhancedRequirements.deviceBiometricRequired == true)
        #expect(context.riskAssessment.enhancedRequirements.documentScanRequired == false)
    }

    @Test("Continuing enhanced verification submits final result")
    func continueEnhancedVerificationCompletes() async {
        let riskEngine = MockEKYCRiskEngine()
        await riskEngine.setScenario(riskLevel: .high)

        var completed: EKYCResult?
        let viewModel = makeViewModel(riskEngine: riskEngine, onComplete: { completed = $0 })
        await viewModel.startVerification()

        guard case .enhancedRequired(let context) = viewModel.state else {
            Issue.record("Expected enhancedRequired state")
            return
        }

        await viewModel.continueEnhancedVerification(context: context)

        guard case .success(let result) = viewModel.state else {
            Issue.record("Expected success state after enhanced verification")
            return
        }
        #expect(result.enhancedResults?.deviceBiometricPassed == true)
        #expect(result.enhancedResults?.documentScanPassed == true)
        #expect(completed?.enhancedResults?.documentScanPassed == true)
    }

    private func makeViewModel(
        riskEngine: MockEKYCRiskEngine = MockEKYCRiskEngine(),
        onComplete: @escaping (EKYCResult) -> Void = { _ in }
    ) -> EKYCViewModel {
        EKYCViewModel(
            ekycService: MockEKYCService(),
            riskEngine: riskEngine,
            deviceContextEncryptor: MockEKYCDeviceContextEncryptor(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService(),
            onboardingStateStore: OnboardingStateStore(suiteName: "test.ekyc.viewmodel"),
            methodStatuses: nil,
            onBack: {},
            onComplete: onComplete
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCViewModelTests
```

Expected: FAIL with `cannot find 'EKYCViewModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Modules/Onboarding/ViewModels/EKYCViewModel.swift`:

```swift
import Foundation
import UIKit

@MainActor
final class EKYCViewModel: ObservableObject {
    @Published private(set) var state: EKYCViewState = .idle
    @Published private(set) var selectedMethod: EKYCMethod = .uaepass
    @Published private(set) var methodStatuses: [EKYCMethod: EKYCMethodStatus] = [
        .uaepass: .ready,
        .deviceBiometrics: .ready,
        .documentScan: .ready
    ]
    @Published private(set) var errorMessage: String?
    @Published private(set) var verificationProgress: Double = 0

    private let ekycService: any EKYCServicing
    private let riskEngine: any EKYCRiskEngineServicing
    private let deviceContextEncryptor: any EKYCDeviceContextEncrypting
    private let deviceBiometricService: any DeviceBiometricServicing
    private let documentOCRService: any DocumentOCRServicing
    private let onboardingStateStore: OnboardingStateStore

    let onBack: () -> Void
    let onComplete: (EKYCResult) -> Void

    init(
        ekycService: any EKYCServicing,
        riskEngine: any EKYCRiskEngineServicing,
        deviceContextEncryptor: any EKYCDeviceContextEncrypting,
        deviceBiometricService: any DeviceBiometricServicing,
        documentOCRService: any DocumentOCRServicing,
        onboardingStateStore: OnboardingStateStore,
        methodStatuses: [EKYCMethod: EKYCMethodStatus]? = nil,
        onBack: @escaping () -> Void,
        onComplete: @escaping (EKYCResult) -> Void
    ) {
        self.ekycService = ekycService
        self.riskEngine = riskEngine
        self.deviceContextEncryptor = deviceContextEncryptor
        self.deviceBiometricService = deviceBiometricService
        self.documentOCRService = documentOCRService
        self.onboardingStateStore = onboardingStateStore
        if let methodStatuses {
            self.methodStatuses = methodStatuses
        }
        self.onBack = onBack
        self.onComplete = onComplete
    }

    func selectMethod(_ method: EKYCMethod) {
        guard methodStatuses[method] == .ready else { return }
        selectedMethod = method
        state = .preparing(method: method, permission: nil)
    }

    func startVerification() async {
        state = .verifying(method: selectedMethod)
        errorMessage = nil
        verificationProgress = 0

        do {
            let primaryResult = try await performPrimaryVerification(selectedMethod)
            verificationProgress = 0.5
            state = .assessing(primaryResult: primaryResult)
            let riskResponse = try await performRiskAssessment(primaryResult)
            verificationProgress = 0.7
            let context = EKYCFlowContext(primaryResult: primaryResult, riskAssessment: riskResponse)

            if riskResponse.enhancedRequirements == .none {
                state = .submitting(context: context, finalResult: primaryResult)
                try await submitAndComplete(primaryResult, assessmentId: riskResponse.assessmentId)
            } else {
                state = .enhancedRequired(context: context)
            }
        } catch {
            let ekycError = error as? EKYCError ?? .unknown(message: error.localizedDescription)
            state = .failure(error: ekycError)
            errorMessage = ekycError.localizedDescription
        }
    }

    func retryVerification() async {
        await startVerification()
    }

    func continueEnhancedVerification(context: EKYCFlowContext) async {
        let requirements = context.riskAssessment.enhancedRequirements
        state = .performingEnhanced(context: context)
        do {
            let enhancedResults = try await performEnhancedVerification(requirements: requirements)
            verificationProgress = 1.0
            let finalResult = EKYCResult(
                method: context.primaryResult.method,
                identityID: context.primaryResult.identityID,
                verifiedAt: context.primaryResult.verifiedAt,
                metadata: context.primaryResult.metadata,
                enhancedResults: enhancedResults
            )
            state = .submitting(context: context, finalResult: finalResult)
            try await submitAndComplete(finalResult, assessmentId: context.riskAssessment.assessmentId)
        } catch {
            let ekycError = error as? EKYCError ?? .unknown(message: error.localizedDescription)
            state = .failure(error: ekycError)
            errorMessage = ekycError.localizedDescription
        }
    }

    private func performPrimaryVerification(_ method: EKYCMethod) async throws -> EKYCResult {
        switch method {
        case .uaepass:
            return try await ekycService.verifyWithUAEPass()
        case .deviceBiometrics:
            throw EKYCError.deviceBiometricFailed(reason: "Device biometrics requires prior UAE Pass or Document verification")
        case .documentScan:
            let documents = try await ekycService.scanDocuments(types: [.emiratesID])
            guard let first = documents.first else {
                throw EKYCError.documentScanFailed(reason: "No document scanned")
            }
            return EKYCResult(
                method: .documentScan,
                identityID: first.extractedData.documentNumber ?? "unknown",
                verifiedAt: first.scanTimestamp,
                metadata: first.extractedData,
                enhancedResults: nil
            )
        }
    }

    private func performRiskAssessment(_ result: EKYCResult) async throws -> RiskAssessmentResponse {
        let encryptedDeviceContext = try await deviceContextEncryptor.encrypt(collectDeviceContext())
        let request = RiskAssessmentRequest(
            primaryVerificationResult: result,
            encryptedDeviceContext: encryptedDeviceContext,
            networkInfo: collectNetworkInfo(),
            businessScenario: .newESIMActivation
        )
        return try await riskEngine.assessRisk(request: request)
    }

    private func performEnhancedVerification(requirements: EKYCEnhancedRequirements) async throws -> EKYCEnhancedResults {
        let deviceBiometricPassed: Bool
        if requirements.deviceBiometricRequired {
            deviceBiometricPassed = try await ekycService.verifyWithDeviceBiometrics()
        } else {
            deviceBiometricPassed = false
        }

        if requirements.faceLivenessRequired {
            throw EKYCError.faceLivenessFailed(reason: "Face liveness SDK is not integrated")
        }

        let documents: [ScannedDocument]
        if requirements.documentScanRequired {
            documents = try await ekycService.scanDocuments(types: requirements.documentTypes)
        } else {
            documents = []
        }

        return EKYCEnhancedResults(
            deviceBiometricPassed: deviceBiometricPassed,
            faceLivenessPassed: false,
            documentScanPassed: documents.isEmpty == false,
            scannedDocuments: documents
        )
    }

    private func submitAndComplete(_ result: EKYCResult, assessmentId: String?) async throws {
        let response = try await ekycService.submitVerificationResult(result, assessmentId: assessmentId)
        guard response.success else {
            throw EKYCError.unknown(message: "Verification result rejected")
        }
        state = .success(result: result)
        onComplete(result)
    }

    private func collectDeviceContext() -> DeviceContext {
        DeviceContext(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    private func collectNetworkInfo() -> RiskAssessmentRequest.NetworkInfo {
        RiskAssessmentRequest.NetworkInfo(connectionType: "unknown", carrierName: nil)
    }
}
```

- [ ] **Step 4: Add files to the Xcode project**

Append to `ioscrmapp/add_ekyc_files.rb`:

```ruby
view_model_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'ViewModels'])

add_file(view_model_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/ViewModels/EKYCViewModel.swift")
add_file(test_group, test_target, "#{base_path}/Tests/OnboardingTests/EKYCViewModelTests.swift")
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: file references added successfully.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCViewModelTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/ViewModels/EKYCViewModel.swift Tests/OnboardingTests/EKYCViewModelTests.swift Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: add ekyc viewmodel flow"
```

---

### Task 7: 实现 eKYC 页面组件与主视图

**Files:**
- Create: `ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift`
- Create: `ioscrmapp/Modules/Onboarding/Views/EKYCView.swift`
- Modify: `ioscrmapp/add_ekyc_files.rb`
- Test: `Tests/OnboardingTests/EKYCViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Tests/OnboardingTests/EKYCViewModelTests.swift`:

```swift
@Test("Unavailable methods are ignored by selection")
func unavailableMethodSelectionIsIgnored() {
    let viewModel = EKYCViewModel(
        ekycService: MockEKYCService(),
        riskEngine: MockEKYCRiskEngine(),
        deviceContextEncryptor: MockEKYCDeviceContextEncryptor(),
        deviceBiometricService: MockDeviceBiometricService(),
        documentOCRService: MockDocumentOCRService(),
        onboardingStateStore: OnboardingStateStore(suiteName: "test.ekyc.unavailable"),
        methodStatuses: [.uaepass: .ready, .deviceBiometrics: .comingSoon, .documentScan: .ready],
        onBack: {},
        onComplete: { _ in }
    )

    viewModel.selectMethod(.deviceBiometrics)
    #expect(viewModel.selectedMethod == .uaepass)
    #expect(viewModel.state == .idle)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCViewModelTests
```

Expected: FAIL if selection guard behavior is not yet correct.

- [ ] **Step 3: Write minimal implementation**

Create `ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift`:

```swift
import SwiftUI

private enum EkycPalette {
    static let background = Color(hex: 0x050505)
    static let red = Color(hex: 0xE10600)
    static let muted = Color.white.opacity(0.55)
    static let stroke = Color.white.opacity(0.12)
}

struct EKYCBackground: View {
    var body: some View {
        ZStack {
            EkycPalette.background
            RadialGradient(
                colors: [EkycPalette.red.opacity(0.22), .clear],
                center: UnitPoint(x: 0.82, y: 0.08),
                startRadius: 12,
                endRadius: 260
            )
            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: UnitPoint(x: 0.15, y: 0.92),
                startRadius: 10,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
    }
}

struct EKYCHeader: View {
    let safeTop: CGFloat
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(EkycPalette.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Image("RedBullLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 160, height: 28)
        }
        .padding(.top, max(safeTop - 10, 10))
        .padding(.horizontal, 24)
    }
}

struct EKYCMethodCard: View {
    let method: EKYCMethod
    let status: EKYCMethodStatus
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? EkycPalette.red : Color.white.opacity(0.10))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: method.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(method.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(EkycPalette.muted)
                        .lineLimit(2)
                }

                Spacer()

                if case .ready = status {
                    Circle()
                        .stroke(isSelected ? EkycPalette.red : Color.white.opacity(0.28), lineWidth: 2)
                        .background(isSelected ? EkycPalette.red : .clear, in: Circle())
                        .frame(width: 22, height: 22)
                        .overlay {
                            if isSelected {
                                Circle().fill(Color.white).frame(width: 8, height: 8)
                            }
                        }
                } else {
                    Text(statusText)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.white.opacity(0.10), in: Capsule())
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isSelected ? EkycPalette.red.opacity(0.6) : EkycPalette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(status != .ready)
    }

    private var statusText: String {
        switch status {
        case .ready:
            return "READY"
        case .comingSoon:
            return "SOON"
        case .unavailable:
            return "LOCKED"
        }
    }
}

struct EKYCPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(Color.black)
                }
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(EkycPalette.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EnhancedVerificationStep: View {
    let icon: String
    let title: String
    let description: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCompleted ? Color.green.opacity(0.24) : Color.white.opacity(0.08))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: isCompleted ? "checkmark" : icon)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(EkycPalette.muted)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EKYCProgressIndicator: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 76, height: 76)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(EkycPalette.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(-90))
        }
    }
}
```

Create `ioscrmapp/Modules/Onboarding/Views/EKYCView.swift`:

```swift
import SwiftUI

struct EKYCView: View {
    @StateObject private var viewModel: EKYCViewModel

    init(viewModel: EKYCViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EKYCBackground()
                switch viewModel.state {
                case .idle:
                    idleContent(proxy: proxy)
                case let .preparing(method, permission):
                    preparingContent(method: method, permission: permission)
                case let .verifying(method):
                    loadingContent(title: "Verifying with \(method.title)", subtitle: "Please wait while we verify your identity...")
                case .assessing:
                    loadingContent(title: "Security Assessment", subtitle: "Checking security requirements...")
                case let .enhancedRequired(context):
                    enhancedRequiredContent(context: context, proxy: proxy)
                case .performingEnhanced:
                    loadingContent(title: "Completing additional checks", subtitle: "Please wait while we complete the required verification steps.")
                case .submitting:
                    loadingContent(title: "Submitting verification", subtitle: "Saving your eKYC result securely.")
                case .success:
                    loadingContent(title: "Verification Complete", subtitle: "Identity verified successfully")
                case .failure:
                    failureContent()
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    private func idleContent(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EKYCHeader(safeTop: proxy.safeAreaInsets.top, onBack: viewModel.onBack)
            VStack(alignment: .leading, spacing: 10) {
                Text("IDENTITY CHECK")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.42))
                Text("Verify with UAE Pass")
                    .font(.system(size: 34, weight: .heavy))
                    .italic()
                    .foregroundColor(.white)
                Text("Your device is ready for eSIM. Now verify your identity before choosing a number or porting in.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.62))
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)

            VStack(spacing: 12) {
                ForEach(EKYCMethod.allCases) { method in
                    EKYCMethodCard(
                        method: method,
                        status: viewModel.methodStatuses[method] ?? .ready,
                        isSelected: viewModel.selectedMethod == method,
                        onTap: { viewModel.selectMethod(method) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            EKYCPrimaryButton(title: "VERIFY & CONTINUE", isLoading: false) {
                Task { await viewModel.startVerification() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16))
        }
    }

    private func preparingContent(method: EKYCMethod, permission: EKYCPermission?) -> some View {
        loadingContent(
            title: permission == nil ? "Ready to verify" : "Permission required",
            subtitle: permission == nil
            ? "Continue with \(method.title). We will check required permissions before starting."
            : "\(method.title) needs \(permission?.rawValue ?? "permission") access to continue."
        )
    }

    private func enhancedRequiredContent(context: EKYCFlowContext, proxy: GeometryProxy) -> some View {
        let requirements = context.riskAssessment.enhancedRequirements
        return VStack(alignment: .leading, spacing: 18) {
            EKYCHeader(safeTop: proxy.safeAreaInsets.top, onBack: viewModel.onBack)
            VStack(alignment: .leading, spacing: 10) {
                Text("ADDITIONAL CHECKS")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.42))
                Text("Additional Verification Required")
                    .font(.system(size: 30, weight: .heavy))
                    .italic()
                    .foregroundColor(.white)
                Text(requirements.isRegulatoryMandatory ? "Regulatory requirement: additional verification is mandatory for this transaction." : "For enhanced security, please complete the following:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            VStack(spacing: 12) {
                if requirements.deviceBiometricRequired {
                    EnhancedVerificationStep(icon: "faceid", title: "Device Biometrics", description: "Confirm the current device holder", isCompleted: false)
                }
                if requirements.faceLivenessRequired {
                    EnhancedVerificationStep(icon: "person.crop.circle.badge.checkmark", title: "Face Liveness", description: "Complete camera liveness and face match", isCompleted: false)
                }
                if requirements.documentScanRequired {
                    ForEach(requirements.documentTypes, id: \.self) { type in
                        EnhancedVerificationStep(icon: "person.text.rectangle", title: "Scan \(type.rawValue)", description: "Use camera to scan your document", isCompleted: false)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            EKYCPrimaryButton(title: "Continue Verification", isLoading: false) {
                Task { await viewModel.continueEnhancedVerification(context: context) }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16))
        }
    }

    private func loadingContent(title: String, subtitle: String) -> some View {
        VStack(spacing: 28) {
            EKYCProgressIndicator(progress: max(viewModel.verificationProgress, 0.15))
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureContent() -> some View {
        VStack(spacing: 28) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 62, weight: .bold))
                .foregroundColor(.red)
            Text("Verification Failed")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)
            Text(viewModel.errorMessage ?? "An error occurred")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.62))
                .multilineTextAlignment(.center)
            EKYCPrimaryButton(title: "TRY AGAIN", isLoading: false) {
                Task { await viewModel.retryVerification() }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 4: Add files to the Xcode project**

Append to `ioscrmapp/add_ekyc_files.rb`:

```ruby
view_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Views'])

add_file(view_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift")
add_file(view_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Views/EKYCView.swift")
```

Run:
```bash
ruby "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/add_ekyc_files.rb"
```

Expected: both view files added.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCViewModelTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift ioscrmapp/Modules/Onboarding/Views/EKYCView.swift Tests/OnboardingTests/EKYCViewModelTests.swift ioscrmapp/add_ekyc_files.rb
git commit -m "feat: add ekyc onboarding ui"
```

---

### Task 8: 将 eKYC 页面接入 Onboarding 流程和依赖组合根

**Files:**
- Modify: `ioscrmapp/Modules/Onboarding/Views/EntryContainerView.swift`
- Modify: `ioscrmapp/Services/AppServices.swift`
- Modify: `ioscrmapp/ContentView.swift`
- Test: `Tests/OnboardingTests/EntryViewModelTests.swift`

- [ ] **Step 1: Write the protection test**

Append to `Tests/OnboardingTests/EntryViewModelTests.swift`:

```swift
@MainActor
@Test("EntryViewModel moves from eKYC to personalization after verification completes")
func viewModelTransitionsFromEKYCToPersonalization() async throws {
    let store = OnboardingStateStore(suiteName: "test.vm.ekyc.complete")
    let viewModel = EntryViewModel(onboardingStateStore: store)
    viewModel.handleGetStarted()
    #expect(viewModel.step == .ekycVerification)
    viewModel.completeEKYCVerification()
    #expect(viewModel.step == .personalization)
}
```

- [ ] **Step 2: Run test to verify current routing still passes**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EntryViewModelTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 3: Replace placeholder eKYC view with real EKYCView**

In `ioscrmapp/Modules/Onboarding/Views/EntryContainerView.swift`, change the initializer signature and the `.ekycVerification` branch:

```swift
struct EntryContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: EntryViewModel

    private let sessionStore: SessionStore
    private let authService: any AuthServicing
    private let uaePassService: UAEPassServicing
    private let onboardingStateStore: OnboardingStateStore
    private let ekycServiceFactory: () -> any EKYCServicing
    private let riskEngineFactory: () -> any EKYCRiskEngineServicing
    private let deviceContextEncryptorFactory: () -> any EKYCDeviceContextEncrypting
    private let deviceBiometricServiceFactory: () -> any DeviceBiometricServicing
    private let documentOCRServiceFactory: () -> any DocumentOCRServicing

    init(
        sessionStore: SessionStore,
        authService: any AuthServicing,
        uaePassService: UAEPassServicing,
        onboardingStateStore: OnboardingStateStore = OnboardingStateStore(),
        ekycServiceFactory: @escaping () -> any EKYCServicing,
        riskEngineFactory: @escaping () -> any EKYCRiskEngineServicing,
        deviceContextEncryptorFactory: @escaping () -> any EKYCDeviceContextEncrypting,
        deviceBiometricServiceFactory: @escaping () -> any DeviceBiometricServicing,
        documentOCRServiceFactory: @escaping () -> any DocumentOCRServicing
    ) {
        self.sessionStore = sessionStore
        self.authService = authService
        self.uaePassService = uaePassService
        self.onboardingStateStore = onboardingStateStore
        self.ekycServiceFactory = ekycServiceFactory
        self.riskEngineFactory = riskEngineFactory
        self.deviceContextEncryptorFactory = deviceContextEncryptorFactory
        self.deviceBiometricServiceFactory = deviceBiometricServiceFactory
        self.documentOCRServiceFactory = documentOCRServiceFactory
        _viewModel = StateObject(wrappedValue: EntryViewModel(onboardingStateStore: onboardingStateStore))
    }
```

Then replace only the `.ekycVerification` branch:

```swift
case .ekycVerification:
    EKYCView(
        viewModel: EKYCViewModel(
            ekycService: ekycServiceFactory(),
            riskEngine: riskEngineFactory(),
            deviceContextEncryptor: deviceContextEncryptorFactory(),
            deviceBiometricService: deviceBiometricServiceFactory(),
            documentOCRService: documentOCRServiceFactory(),
            onboardingStateStore: onboardingStateStore,
            methodStatuses: nil,
            onBack: { viewModel.resetToWelcome() },
            onComplete: { _ in viewModel.completeEKYCVerification() }
        )
    )
```

Keep all other switch branches unchanged.

- [ ] **Step 4: Wire eKYC dependencies into AppServices and ContentView**

Append to `ioscrmapp/Services/AppServices.swift`:

```swift
extension AppServices {
    func makeUAEPassOAuthHandler() -> any UAEPassOAuthHandling {
        MockUAEPassOAuthHandler()
    }

    func makeDeviceBiometricService() -> any DeviceBiometricServicing {
        DeviceBiometricService()
    }

    func makeDocumentOCRService() -> any DocumentOCRServicing {
        DocumentOCRService()
    }

    func makeEKYCDeviceContextEncryptor() -> any EKYCDeviceContextEncrypting {
        EKYCDeviceContextEncryptor()
    }

    func makeEKYCRiskEngine() -> any EKYCRiskEngineServicing {
        MockEKYCRiskEngine()
    }

    func makeEKYCService() -> any EKYCServicing {
        EKYCService(
            uaePassService: uaePassService,
            oauthHandler: makeUAEPassOAuthHandler(),
            deviceBiometricService: makeDeviceBiometricService(),
            documentOCRService: makeDocumentOCRService()
        )
    }
}
```

Modify the unauthenticated branch in `ioscrmapp/ContentView.swift`:

```swift
let onboardingServices = AppServices(configuration: AppConfig.current.serviceConfiguration)

EntryContainerView(
    sessionStore: sessionStore,
    authService: authService,
    uaePassService: uaePassService,
    ekycServiceFactory: { onboardingServices.makeEKYCService() },
    riskEngineFactory: { onboardingServices.makeEKYCRiskEngine() },
    deviceContextEncryptorFactory: { onboardingServices.makeEKYCDeviceContextEncryptor() },
    deviceBiometricServiceFactory: { onboardingServices.makeDeviceBiometricService() },
    documentOCRServiceFactory: { onboardingServices.makeDocumentOCRService() }
)
```

- [ ] **Step 5: Run tests and a focused build**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EntryViewModelTests -only-testing:ioscrmappTests/EKYCViewModelTests -only-testing:ioscrmappTests/EKYCServiceTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

Run:
```bash
xcodebuild -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Develop" -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/Views/EntryContainerView.swift ioscrmapp/Services/AppServices.swift ioscrmapp/ContentView.swift Tests/OnboardingTests/EntryViewModelTests.swift
git commit -m "feat: integrate ekyc into onboarding flow"
```

---

### Task 9: 验证 UI、补齐演示路径并做最终检查

**Files:**
- Modify: `ioscrmapp/Modules/Onboarding/Views/EKYCView.swift`
- Modify: `ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift`
- Reference: `figma/ekyc.html`

- [ ] **Step 1: Build the app for simulator validation**

Run:
```bash
xcodebuild -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Develop" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Launch in Xcode and validate the golden path manually**

Run:
```bash
open "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj"
```

In Xcode, run scheme `ioscrmapp-Develop` on `iPhone 16` simulator and verify:
- Welcome 页点击 `Get Started` 进入 eKYC
- eKYC 页面视觉接近 `figma/ekyc.html`
- 选择 `UAE Pass` 后进入主验证
- Mock 风险等级为 low 时直接进入 Personalization
- 把 `MockEKYCRiskEngine` 改为 medium/high 后能进入增强认证页
- 增强认证继续后回到成功并进入 Personalization

Expected: Onboarding flow is `Welcome → eKYC → Personalization` with no dead-end states.

- [ ] **Step 3: Tune any mismatched UI text or layout minimally**

If the page does not match `figma/ekyc.html`, make only focused edits in `ioscrmapp/Modules/Onboarding/Views/EKYCView.swift` and `ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift`, for example:

```swift
Text("Verify with UAE Pass")
    .font(.system(size: 34, weight: .heavy))
    .italic()
    .foregroundColor(.white)

EKYCPrimaryButton(title: "VERIFY & CONTINUE", isLoading: false) {
    Task { await viewModel.startVerification() }
}
```

Keep changes limited to typography, spacing, colors, borders, and CTA wording.

- [ ] **Step 4: Run the full eKYC-related test set again**

Run:
```bash
xcodebuild test -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Test" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ioscrmappTests/EKYCModelsTests -only-testing:ioscrmappTests/EKYCServiceTests -only-testing:ioscrmappTests/EKYCViewModelTests -only-testing:ioscrmappTests/EntryViewModelTests
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 5: Run final develop build**

Run:
```bash
xcodebuild -project "/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj" -scheme "ioscrmapp-Develop" -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ioscrmapp/Modules/Onboarding/Views/EKYCView.swift ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift
git commit -m "feat: finalize ekyc onboarding demo"
```

---

## Self-Review

### 1. Spec coverage
- Welcome → eKYC → Personalization 路由：Task 8
- UAE Pass 主认证：Task 5
- Device Biometrics 增强认证：Task 3 + Task 6
- Document OCR 增强/降级路径：Task 3 + Task 6
- 风险引擎动态增强：Task 2 + Task 6
- 设备上下文加密：Task 4 + Task 6
- redBolt 风格 UI：Task 7 + Task 9
- Mock 环境与测试：Task 2, 3, 5, 6
- 兼容现有项目组合根：Task 8
- Xcode 工程文件维护：Task 1–8 中每次新增文件都通过 `add_ekyc_files.rb` 纳入

### 2. Placeholder scan
- 无 `TODO` / `TBD`
- 每个任务都有明确文件路径、测试代码、命令与预期结果
- 没有依赖隐式上下文的 “similar to task N” 描述

### 3. Type consistency
- `EKYCMethod` / `EKYCViewState` / `EKYCFlowContext` 在模型、ViewModel、View 中命名一致
- `EKYCServicing.submitVerificationResult(_:assessmentId:)` 在协议、服务、ViewModel 中签名一致
- `UAEPassOAuthHandling.performOAuth(config:)` 在协议、mock、service 中签名一致
- `EKYCDeviceContextEncrypting.encrypt(_:)` 在协议、mock、service 中签名一致

---

Plan complete and saved to `docs/superpowers/plans/2026-05-10-ekyc-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**