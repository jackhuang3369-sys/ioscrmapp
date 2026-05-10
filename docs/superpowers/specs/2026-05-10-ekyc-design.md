---
title: 阿联酋用户身份核验模块设计
date: 2026-05-10
status: draft
---

# 阿联酋用户身份核验模块设计文档

## 1. 概述

### 1.1 背景

面向阿联酋用户，实现符合当地合规要求的多渠道身份核验能力，作为 Red Bull Mobile eSIM 入网流程的关键环节。

### 1.2 流程定位

```
Onboarding 流程：
WelcomeView → EKYCView → PersonalizationView → NumberSelection/PortIn
```

eKYC 作为 `EntryStep.ekycVerification` 的实现页面，位于 `Modules/Onboarding/Views/`。

### 1.3 认证架构

采用"主认证 + 后端风险引擎驱动动态增强 + Fallback降级"的多源身份认证架构：

| 验证方式 | 角色 | 说明 |
|----------|------|------|
| UAE Pass | 主认证 | 阿联酋官方电子身份，首选路径 |
| Device Biometrics | 设备持有人确认/Fallback | Face ID / Touch ID 本机生物识别，只证明当前设备持有人通过验证 |
| Face Liveness | 增强认证 | 相机活体检测 + 后端人脸比对，后端风险引擎触发 |
| 证件 OCR | 增强认证/Fallback | Emirates ID + Passport 扫描 |

> 说明：LocalAuthentication 的 Face ID / Touch ID 不是“人脸核验”，不能证明用户面部与 UAE Pass 或证件照片一致。本文将本机 Face ID / Touch ID 统一命名为 Device Biometrics；真正的人脸核验能力后续由 Face Liveness SDK 或后端服务承接。

---

## 2. 文件结构

### 2.1 第一阶段（核心流程）

```
Modules/Onboarding/
├── Models/
│   └── OnboardingModels.swift          # 扩展 EKYCMethod / EKYCResult / EKYCError 类型
├── ViewModels/
│   ├── EntryViewModel.swift            # 现有，路由逻辑不变
│   └── EKYCViewModel.swift             # 新增，管理验证状态与风险引擎响应
├── Views/
│   ├── EntryContainerView.swift        # 现有，替换 placeholder OnboardingEKYCView
│   └── EKYCView.swift                  # 新增，主页面（选择+执行）
└── Services/
    ├── EKYCService.swift               # 新增，包装 eKYC 业务结果与提交
    ├── EKYCDeviceContextEncryptor.swift # 新增，风险评估设备上下文加密
    ├── EKYCRiskEngineServicing.swift   # 新增，风险引擎协议
    └── MockEKYCRiskEngine.swift        # 新增，Demo 阶段模拟后端风险评分

Services/（全局服务，不迁移）
├── UAEPass/
│   ├── UAEPassServicing.swift          # 现有，被 Auth 和 eKYC 共用
│   ├── MockUAEPassService.swift        # 现有
│   └── UAEPassOAuthHandler.swift       # 新增，抽取共享 OAuth 处理组件
├── DeviceBiometricService.swift        # 新增，LocalAuthentication 封装
├── FaceLivenessService.swift           # 后续新增，相机活体与人脸比对封装
└── DocumentOCRService.swift            # 新增，VisionKit 封装
```

### 2.2 后续扩展（独立子页面）

当交互复杂度增加时拆分：

```
Modules/Onboarding/Views/
├── EKYCUAEPassView.swift               # UAE Pass 执行子页面
├── EKYCDeviceBiometricView.swift       # 本机生物识别执行子页面
├── EKYCFaceLivenessView.swift          # 活体检测执行子页面
├── EKYCDocumentScanView.swift          # 证件扫描执行子页面
```

---

## 3. 数据模型

### 3.1 核心类型定义

```swift
/// eKYC 验证方式
enum EKYCMethod: String, CaseIterable, Identifiable, Sendable {
    case uaepass = "UAE Pass"
    case deviceBiometrics = "Device Biometrics"
    case documentScan = "Document Scan"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .uaepass: return "checkmark.shield.fill"
        case .deviceBiometrics: return "faceid"
        case .documentScan: return "person.text.rectangle"
        }
    }
    
    var title: String { rawValue }
    
    var subtitle: String {
        switch self {
        case .uaepass: return "Fast verification for UAE mobile onboarding."
        case .deviceBiometrics: return "Confirm the current device holder with Face ID or Touch ID."
        case .documentScan: return "Scan Emirates ID or Passport for manual processing."
        }
    }
}

/// 验证方式可用状态
enum EKYCMethodStatus: Equatable {
    case ready
    case comingSoon
    case unavailable(reason: String)
}

/// eKYC 流程上下文，所有后续步骤依赖的数据必须跟随状态保存，避免页面重建后丢失。
struct EKYCFlowContext: Equatable, Sendable, Codable {
    let primaryResult: EKYCResult
    let riskAssessment: RiskAssessmentResponse
}

/// eKYC 页面状态
enum EKYCViewState: Equatable {
    case idle                                           // 展示选择卡片
    case preparing(method: EKYCMethod, permission: EKYCPermission?) // 权限检查、跳转确认或 SDK 准备
    case verifying(method: EKYCMethod)                  // 执行主验证
    case assessing(primaryResult: EKYCResult)           // 等待风险引擎返回
    case enhancedRequired(context: EKYCFlowContext)     // 展示增强认证要求，等待用户继续
    case performingEnhanced(context: EKYCFlowContext)   // 正在执行增强认证
    case submitting(context: EKYCFlowContext, finalResult: EKYCResult) // 提交最终 eKYC 结果
    case success(result: EKYCResult)                    // 全部验证成功
    case failure(error: EKYCError)                      // 验证失败
}

/// 状态设计原则：不再用 ViewModel 私有 pending 变量保存流程上下文；任何跨步骤继续所需的数据都必须在状态关联值中。
/// 状态按“准备 / 主验证 / 风险评估 / 增强验证 / 提交 / 终态”组织，避免把每个权限弹窗拆成独立状态。

/// eKYC 相关权限
enum EKYCPermission: String, Equatable, Sendable {
    case camera
    case biometrics
    case uaepassApp
}

/// 增强认证要求（后端风险引擎返回）
struct EKYCEnhancedRequirements: Equatable, Sendable, Codable {
    let deviceBiometricRequired: Bool
    let faceLivenessRequired: Bool      // 真正人脸活体/比对能力，区别于本机 Device Biometrics
    let documentScanRequired: Bool
    let documentTypes: [DocumentType]   // 需要扫描的证件类型
    let isRegulatoryMandatory: Bool     // 监管强制场景标识
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

/// 风险等级
enum RiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

/// 证件类型
enum DocumentType: String, Codable, CaseIterable, Sendable {
    case emiratesID = "Emirates ID"
    case passport = "Passport"
}

/// eKYC 验证结果
struct EKYCResult: Equatable, Sendable, Codable {
    let method: EKYCMethod
    let identityID: String              // UAE Pass 返回的用户标识
    let verifiedAt: Date
    let metadata: EKYCMetadata?
    let enhancedResults: EKYCEnhancedResults?
}

/// eKYC 元数据
struct EKYCMetadata: Equatable, Sendable, Codable {
    let fullName: String?
    let phoneNumber: String?
    let documentType: String?
    let documentNumber: String?
    let documentExpiryDate: String?
}

/// 增强认证结果
struct EKYCEnhancedResults: Equatable, Sendable, Codable {
    let deviceBiometricPassed: Bool
    let faceLivenessPassed: Bool
    let documentScanPassed: Bool
    let scannedDocuments: [ScannedDocument]
}

/// 扫描证件结果
struct ScannedDocument: Equatable, Sendable, Codable {
    let type: DocumentType
    let extractedData: EKYCMetadata
    let scanTimestamp: Date
}

/// eKYC 错误类型
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
        case .uaepassFailed(let reason): return "UAE Pass verification failed: \(reason)"
        case .deviceBiometricFailed(let reason): return "Device biometric verification failed: \(reason)"
        case .faceLivenessFailed(let reason): return "Face liveness verification failed: \(reason)"
        case .documentScanFailed(let reason): return "Document scan failed: \(reason)"
        case .riskAssessmentFailed(let reason): return "Risk assessment failed: \(reason)"
        case .networkUnavailable: return "Network unavailable"
        case .permissionDenied(let permission): return "Permission denied: \(permission)"
        case .timeout: return "Verification timeout"
        case .userCancelled: return "User cancelled verification"
        case .unknown(let message): return message
        }
    }
}
```

> 实现约束：如果 `RiskAssessmentRequest` / `RiskAssessmentResponse` 直接复用上述本地模型，`EKYCResult`、`EKYCMetadata`、`EKYCEnhancedResults`、`ScannedDocument`、`EKYCEnhancedRequirements` 都必须符合 `Codable`。如果后端 DTO 与本地 UI 模型字段不完全一致，则应新增 `RiskAssessmentRequestDTO` / `RiskAssessmentResponseDTO`，不要让不可编码的 UI 状态进入网络层。

---

## 4. 服务协议

### 4.1 EKYC 服务协议

```swift
/// eKYC 业务服务协议
protocol EKYCServicing: Sendable {
    /// 执行 UAE Pass 验证
    func verifyWithUAEPass() async throws -> EKYCResult
    
    /// 执行本机生物识别确认
    func verifyWithDeviceBiometrics() async throws -> Bool
    
    /// 执行证件扫描
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument]
    
    /// 提交验证结果供后端校验（Demo 阶段本地模拟）
    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse
}
```

```swift
/// eKYC 提交响应
struct EKYCSubmitResponse: Equatable, Sendable, Codable {
    let success: Bool
    let verificationId: String
    let nextStep: String
}
```

### 4.2 风险引擎协议

```swift
/// 风险评估请求
struct RiskAssessmentRequest: Sendable, Codable {
    let primaryVerificationResult: EKYCResult
    let encryptedDeviceContext: EncryptedPayload
    let networkInfo: NetworkInfo
    let businessScenario: BusinessScenario
    
    struct NetworkInfo: Sendable, Codable {
        let connectionType: String  // wifi, cellular, unknown
        let carrierName: String?
    }
    
    enum BusinessScenario: String, Sendable, Codable {
        case newESIMActivation
        case portIn
        case simReplacement
        case highValueTransaction
    }
}

/// 加密后的设备上下文载荷
struct EncryptedPayload: Sendable, Codable, Equatable {
    let algorithm: String       // 例如 rsa-pkcs1-v1_5，与 RegistrationRequestEncryptor 保持一致
    let keyId: String?          // 后端密钥版本，可为空
    let ciphertext: String      // Base64 编码密文
}

/// 明文设备上下文仅存在于本地内存，不能直接进入网络请求。
struct DeviceContext: Sendable, Codable, Equatable {
    let deviceId: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
}

/// eKYC 设备上下文加密协议
protocol EKYCDeviceContextEncrypting: Sendable {
    /// 参考 RegistrationRequestEncryptor 的 RSA 公钥加密方式，输出后端可解密的密文载荷。
    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload
}

/// 风险评估响应
struct RiskAssessmentResponse: Sendable, Codable {
    let riskLevel: RiskLevel
    let enhancedRequirements: EKYCEnhancedRequirements
    let assessmentId: String
    let assessedAt: Date
}

/// 风险引擎服务协议
protocol EKYCRiskEngineServicing: Sendable {
    /// 执行风险评估
    func assessRisk(request: RiskAssessmentRequest) async throws -> RiskAssessmentResponse
}
```

### 4.3 UAE Pass OAuth 共享组件

```swift
/// UAE Pass OAuth 处理器（Auth 和 eKYC 共用）
protocol UAEPassOAuthHandling: Sendable {
    /// 执行完整 OAuth 流程并返回用户信息。生产与 Mock 通过依赖注入区分，业务服务不包含 #if DEBUG 分支。
    func performOAuth(config: UAEPassConfig) async throws -> CustSubInfo
}

/// OAuth 会话状态，由真实 Handler 内部维护。
struct OAuthSession: Sendable, Equatable {
    let requestId: String
    let state: String
    let initiatedAt: Date
    let config: UAEPassConfig
}
```

生产实现使用 `ASWebAuthenticationSession` 或 UAE Pass App deeplink：

1. 根据 `installedFlowAcrValues` 判断是否优先打开 UAE Pass App。
2. 未安装或跳转失败时使用 Safari / `ASWebAuthenticationSession` fallback。
3. 校验回调 URL 的 `state`、`requestId` 和 authorization code。
4. 调用 `UAEPassServicing.loginWithCode()` 换取 `CustSubInfo`。
5. Mock 实现只存在于测试和 Demo 注入层，不能写在 `EKYCService` 的生产实现中。

### 4.4 Device Biometrics 服务

```swift
/// 本机生物识别服务协议
protocol DeviceBiometricServicing: Sendable {
    /// 检查本机生物识别可用性
    func checkAvailability() async -> DeviceBiometricAvailability
    
    /// 执行本机生物识别认证
    func authenticate(reason: String) async throws -> Bool
    
    /// 获取设备支持的生物识别类型
    func supportedBiometricType() -> BiometricType
}

/// 本机生物识别可用性状态
enum DeviceBiometricAvailability: Sendable {
    case available
    case notEnrolled          // 用户未设置 Face ID / Touch ID
    case notAvailable         // 设备不支持
    case lockedOut            // 生物识别已锁定
    case restricted           // 受限制（如家长控制）
}

/// 生物识别类型
enum BiometricType: Sendable {
    case faceID
    case touchID
    case none
}
```

### 4.5 Document OCR 服务

```swift
/// 证件 OCR 服务协议
protocol DocumentOCRServicing: Sendable {
    /// 扫描证件
    func scanDocument(type: DocumentType) async throws -> ScannedDocument
    
    /// 扫描多个证件
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument]
    
    /// 检查相机权限
    func checkCameraPermission() async -> Bool
    
    /// 请求相机权限
    func requestCameraPermission() async -> Bool
}
```

> 边界说明：VisionKit / DataScannerViewController 是 UI 驱动能力，不能完全封装在 actor service 内部。第一阶段可用 Mock 返回扫描结果；真实实现时应由 `EKYCDocumentScanView` 或 Coordinator 负责相机页面、权限弹窗和用户交互，`DocumentOCRServicing` 只负责 OCR 解析、后端校验和结果标准化。

---

## 5. ViewModel 设计

### 5.1 EKYCViewModel

```swift
@MainActor
final class EKYCViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var state: EKYCViewState = .idle
    @Published private(set) var selectedMethod: EKYCMethod = .uaepass
    @Published private(set) var methodStatuses: [EKYCMethod: EKYCMethodStatus] = [
        .uaepass: .ready,
        .deviceBiometrics: .ready,
        .documentScan: .ready
    ]
    @Published private(set) var errorMessage: String?
    @Published private(set) var verificationProgress: Double = 0
    
    // MARK: - Dependencies
    private let ekycService: EKYCServicing
    private let riskEngine: EKYCRiskEngineServicing
    private let deviceContextEncryptor: EKYCDeviceContextEncrypting
    private let deviceBiometricService: DeviceBiometricServicing
    private let documentOCRService: DocumentOCRServicing
    private let onboardingStateStore: OnboardingStateStore
    
    // MARK: - Callbacks
    let onBack: () -> Void
    let onComplete: (EKYCResult) -> Void
    
    // MARK: - Init
    init(
        ekycService: EKYCServicing,
        riskEngine: EKYCRiskEngineServicing,
        deviceContextEncryptor: EKYCDeviceContextEncrypting,
        deviceBiometricService: DeviceBiometricServicing,
        documentOCRService: DocumentOCRServicing,
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
    
    // MARK: - Actions
    
    /// 选择验证方式
    func selectMethod(_ method: EKYCMethod) {
        guard methodStatuses[method] == .ready else { return }
        selectedMethod = method
        state = .preparing(method: method, permission: nil)
    }
    
    /// 开始验证流程
    func startVerification() async {
        state = .verifying(method: selectedMethod)
        errorMessage = nil
        verificationProgress = 0
        
        do {
            let result = try await performPrimaryVerification(selectedMethod)
            verificationProgress = 0.5
            
            // 调用风险引擎评估
            state = .assessing(primaryResult: result)
            let riskResponse = try await performRiskAssessment(result)
            verificationProgress = 0.7
            let context = EKYCFlowContext(primaryResult: result, riskAssessment: riskResponse)
            
            // 根据风险引擎结果展示增强认证要求，等待用户确认后继续。
            if riskResponse.enhancedRequirements == .none {
                state = .submitting(context: context, finalResult: result)
                try await submitAndComplete(result, assessmentId: riskResponse.assessmentId)
            } else {
                state = .enhancedRequired(context: context)
            }
        } catch {
            state = .failure(error: error as? EKYCError ?? .unknown(message: error.localizedDescription))
            errorMessage = error.localizedDescription
        }
    }
    
    /// 重试验证
    func retryVerification() async {
        await startVerification()
    }

    /// 用户确认后执行增强认证。
    func continueEnhancedVerification(context: EKYCFlowContext) async {
        let requirements = context.riskAssessment.enhancedRequirements
        state = .performingEnhanced(context: context)
        do {
            let enhancedResult = try await performEnhancedVerification(requirements: requirements)
            verificationProgress = 1.0
            let finalResult = EKYCResult(
                method: context.primaryResult.method,
                identityID: context.primaryResult.identityID,
                verifiedAt: context.primaryResult.verifiedAt,
                metadata: context.primaryResult.metadata,
                enhancedResults: enhancedResult
            )
            state = .submitting(context: context, finalResult: finalResult)
            try await submitAndComplete(finalResult, assessmentId: context.riskAssessment.assessmentId)
        } catch {
            state = .failure(error: error as? EKYCError ?? .unknown(message: error.localizedDescription))
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    
    private func performPrimaryVerification(_ method: EKYCMethod) async throws -> EKYCResult {
        switch method {
        case .uaepass:
            return try await ekycService.verifyWithUAEPass()
        case .deviceBiometrics:
            // 本机生物识别不能作为实名主认证，需要 UAE Pass 或 Document 先完成。
            throw EKYCError.deviceBiometricFailed(reason: "Device biometrics requires prior UAE Pass or Document verification")
        case .documentScan:
            // Document Scan 作为主认证（降级场景）
            let documents = try await ekycService.scanDocuments(types: [.emiratesID])
            guard let firstDoc = documents.first else {
                throw EKYCError.documentScanFailed(reason: "No document scanned")
            }
            return EKYCResult(
                method: .documentScan,
                identityID: firstDoc.extractedData.documentNumber ?? "unknown",
                verifiedAt: firstDoc.scanTimestamp,
                metadata: firstDoc.extractedData,
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
    
    private func performEnhancedVerification(
        requirements: EKYCEnhancedRequirements
    ) async throws -> EKYCEnhancedResults {
        var deviceBiometricPassed = false
        var faceLivenessPassed = false
        var documents: [ScannedDocument] = []
        
        // 执行本机生物识别确认
        if requirements.deviceBiometricRequired {
            deviceBiometricPassed = try await ekycService.verifyWithDeviceBiometrics()
        }

        // 真正的人脸活体/比对由后续 Face Liveness SDK 或后端服务承接。
        if requirements.faceLivenessRequired {
            throw EKYCError.faceLivenessFailed(reason: "Face liveness SDK is not integrated")
        }
        
        // 执行证件扫描
        if requirements.documentScanRequired {
            documents = try await ekycService.scanDocuments(types: requirements.documentTypes)
        }
        
        return EKYCEnhancedResults(
            deviceBiometricPassed: deviceBiometricPassed,
            faceLivenessPassed: faceLivenessPassed,
            documentScanPassed: !documents.isEmpty,
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
        // Demo 阶段返回模拟值
        RiskAssessmentRequest.NetworkInfo(
            connectionType: "unknown",
            carrierName: nil
        )
    }
}
```

---

## 6. Mock 实现（Demo 阶段）

### 6.1 MockEKYCRiskEngine

```swift
/// Demo 阶段：模拟后端风险引擎
actor MockEKYCRiskEngine: EKYCRiskEngineServicing {
    
    /// 配置模拟返回的风险等级（用于 Demo 测试）
    var simulatedRiskLevel: RiskLevel = .low
    var simulateRegulatoryMandatory: Bool = false
    
    func assessRisk(request: RiskAssessmentRequest) async throws -> RiskAssessmentResponse {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // 根据模拟配置生成响应
        let requirements: EKYCEnhancedRequirements
        
        if simulateRegulatoryMandatory {
            // 监管强制：要求双重认证
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
    
    /// 设置模拟场景（用于 Demo 测试）
    func setScenario(riskLevel: RiskLevel, regulatoryMandatory: Bool = false) {
        self.simulatedRiskLevel = riskLevel
        self.simulateRegulatoryMandatory = regulatoryMandatory
    }
}
```

### 6.2 EKYCService 实现

```swift
actor EKYCService: EKYCServicing {
    private let uaePassService: UAEPassServicing
    private let oauthHandler: UAEPassOAuthHandling
    private let deviceBiometricService: DeviceBiometricServicing
    private let documentOCRService: DocumentOCRServicing
    
    init(
        uaePassService: UAEPassServicing,
        oauthHandler: UAEPassOAuthHandling,
        deviceBiometricService: DeviceBiometricServicing,
        documentOCRService: DocumentOCRServicing
    ) {
        self.uaePassService = uaePassService
        self.oauthHandler = oauthHandler
        self.deviceBiometricService = deviceBiometricService
        self.documentOCRService = documentOCRService
    }
    
    func verifyWithUAEPass() async throws -> EKYCResult {
        // 通过 UAEPassOAuthHandler 执行 OAuth 流程
        // 返回 CustSubInfo 后包装成 EKYCResult
        let custInfo = try await performUAEPassOAuth()
        
        return EKYCResult(
            method: .uaepass,
            identityID: custInfo.userID ?? custInfo.phoneNumber,
            verifiedAt: Date(),
            metadata: EKYCMetadata(
                fullName: custInfo.displayName,
                phoneNumber: custInfo.phoneNumber,
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
        if !hasPermission {
            let granted = await documentOCRService.requestCameraPermission()
            if !granted {
                throw EKYCError.permissionDenied(permission: "Camera")
            }
        }
        
        return try await documentOCRService.scanDocuments(types: types)
    }
    
    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse {
        // Demo 阶段：模拟提交成功
        try await Task.sleep(nanoseconds: 300_000_000)
        return EKYCSubmitResponse(
            success: true,
            verificationId: UUID().uuidString,
            nextStep: "personalization"
        )
    }
    
    private func performUAEPassOAuth() async throws -> CustSubInfo {
        // 获取配置并发起 OAuth
        let config = try await uaePassService.getConfig()
        // 生产和 Mock 行为通过 UAEPassOAuthHandling 依赖注入区分，避免 #if DEBUG 混入生产服务。
        return try await oauthHandler.performOAuth(config: config)
    }
}
```

### 6.3 EKYCDeviceContextEncryptor 实现

```swift
struct EKYCDeviceContextEncryptor: EKYCDeviceContextEncrypting {
    private let registrationEncryptor = RegistrationRequestEncryptor()

    func encrypt(_ context: DeviceContext) async throws -> EncryptedPayload {
        let jsonData = try JSONEncoder().encode(context)
        let plaintext = String(decoding: jsonData, as: UTF8.self)
        let ciphertext = try await registrationEncryptor.encryptPassword(plaintext)
        return EncryptedPayload(
            algorithm: "rsa-pkcs1-v1_5",
            keyId: "registration-public-key-v1",
            ciphertext: ciphertext
        )
    }
}
```

### 6.4 DeviceBiometricService 实现

```swift
import LocalAuthentication

actor DeviceBiometricService: DeviceBiometricServicing {
    /// 每次认证流程通过统一工厂创建 LAContext，避免配置散落在不同方法里。
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
            if let error = error {
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
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if let error = error {
                    let laError = error as? LAError
                    let ekycError: EKYCError
                    switch laError {
                    case .userFallback:
                        ekycError = .userCancelled
                    case .userCancel:
                        ekycError = .userCancelled
                    case .biometryNotEnrolled:
                        ekycError = .permissionDenied(permission: "Device Biometrics not enrolled")
                    case .biometryLockout:
                        ekycError = .deviceBiometricFailed(reason: "Device Biometrics locked out")
                    default:
                        ekycError = .deviceBiometricFailed(reason: error.localizedDescription)
                    }
                    continuation.resume(throwing: ekycError)
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

### 6.5 DocumentOCRService 实现

```swift
import VisionKit
import AVFoundation

actor DocumentOCRService: DocumentOCRServicing {
    
    func checkCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .authorized
    }
    
    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func scanDocument(type: DocumentType) async throws -> ScannedDocument {
        // VisionKit DataScannerViewController 实现
        // 具体实现需要在 View 层配合
        // 这里返回模拟数据用于 Demo
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return ScannedDocument(
            type: type,
            extractedData: mockExtractedData(for: type),
            scanTimestamp: Date()
        )
    }
    
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        var results: [ScannedDocument] = []
        for type in types {
            results.append(try await scanDocument(type: type))
        }
        return results
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

---

## 7. UI 设计

### 7.0 视觉方向

eKYC 页面需要对齐 `figma/redbolt_onboarding_v2.html` 的 redBolt activation mission 风格，而不是继续沿用大面积 Apple Glassmorphism：

- 字体：优先使用压缩、粗体、斜体、全大写的运动感标题风格；系统字体实现时用 `.condensed` / `.black` / `.italic()` 接近。
- 卡片：使用小圆角、细边框、左侧状态条、红/绿状态色，减少大灰色毛玻璃卡片。
- 进度：保留 `Activation Path`、`1 / 4 done`、进度条、done / active / locked 状态。
- CTA：使用高饱和 redBolt 红色、斜切或硬朗按钮形态，文案类似 `VERIFY WITH UAE PASS` + `Step 2 · eKYC identity check`。
- 背景：黑色基底 + 低透明红色环形氛围，不使用大面积灰色半透明块。

> 下面的 SwiftUI 片段用于表达页面状态和组件职责；实际实现时需要用 redBolt 设计 token 替换示例中的 `.ultraThinMaterial`、大圆角和 rounded 字体。

### 7.1 EKYCView 结构

```swift
struct EKYCView: View {
    @StateObject private var viewModel: EKYCViewModel
    @EnvironmentObject private var languageStore: AppLanguageStore
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EKYCBackground()
                
                switch viewModel.state {
                case .idle:
                    idleContent(proxy: proxy)

                case .preparing(method: let method, permission: let permission):
                    preparingContent(method: method, permission: permission, proxy: proxy)
                    
                case .verifying(method: let method):
                    verifyingContent(method: method, proxy: proxy)
                    
                case .assessing(primaryResult: _):
                    assessingContent(proxy: proxy)
                    
                case .enhancedRequired(context: let context):
                    enhancedVerificationContent(context: context, proxy: proxy)

                case .performingEnhanced(context: let context):
                    performingEnhancedVerificationContent(context: context, proxy: proxy)

                case .submitting(context: _, finalResult: _):
                    submittingContent(proxy: proxy)
                    
                case .success(result: let result):
                    successContent(result: result, proxy: proxy)
                    
                case .failure(error: let error):
                    failureContent(error: error, proxy: proxy)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Idle State (选择验证方式)
    
    @ViewBuilder
    private func idleContent(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EKYCHeader(safeTop: proxy.safeAreaInsets.top, onBack: viewModel.onBack)
            
            VStack(alignment: .leading, spacing: 14) {
                Text("IDENTITY CHECK")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.42))
                
                Text("Verify with UAE Pass")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Your device is ready for eSIM. Now verify your identity before choosing a number or porting in.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
            .padding(.horizontal, 26)
            .padding(.top, 30)
            
            // 验证方式选择卡片
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
            .padding(.horizontal, 26)
            .padding(.top, 20)
            
            Spacer()
            
            // 主操作按钮
            EKYCPrimaryButton(
                title: "VERIFY & CONTINUE",
                isLoading: false,
                action: { Task { await viewModel.startVerification() }}
            )
            .padding(.horizontal, 26)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16))
        }
    }
    
    // MARK: - Preparing State

    @ViewBuilder
    private func preparingContent(method: EKYCMethod, permission: EKYCPermission?, proxy: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            Text(permission == nil ? "Ready to verify" : "Permission required")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(.white)

            Text(permission == nil ? "Continue with \(method.title). We will check required permissions before starting." : "\(method.title) needs \(permission?.rawValue ?? "permission") access to continue.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            EKYCPrimaryButton(
                title: "START \(method.title.uppercased())",
                isLoading: false,
                action: { Task { await viewModel.startVerification() }}
            )
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Verifying State
    
    @ViewBuilder
    private func verifyingContent(method: EKYCMethod, proxy: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            EKYCProgressIndicator(progress: viewModel.verificationProgress)
            
            Text("Verifying with \(method.title)")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
            
            Text("Please wait while we verify your identity...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Risk Assessment State
    
    @ViewBuilder
    private func assessingContent(proxy: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            EKYCProgressIndicator(progress: viewModel.verificationProgress)
            
            Text("Security Assessment")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
            
            Text("Checking security requirements...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Enhanced Verification State
    
    @ViewBuilder
    private func enhancedVerificationContent(context: EKYCFlowContext, proxy: GeometryProxy) -> some View {
        let requirements = context.riskAssessment.enhancedRequirements
        VStack(alignment: .leading, spacing: 20) {
            Text("Additional Verification Required")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
            
            if requirements.isRegulatoryMandatory {
                Text("Regulatory requirement: Additional verification is mandatory for this transaction.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("For enhanced security, please complete the following:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // 显示需要完成的增强认证步骤
            VStack(spacing: 12) {
                if requirements.deviceBiometricRequired {
                    EnhancedVerificationStep(
                        icon: "faceid",
                        title: "Device Biometrics",
                        description: "Confirm the current device holder",
                        isCompleted: false
                    )
                }

                if requirements.faceLivenessRequired {
                    EnhancedVerificationStep(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "Face Liveness",
                        description: "Complete camera liveness and face match",
                        isCompleted: false
                    )
                }
                
                if requirements.documentScanRequired {
                    ForEach(requirements.documentTypes, id: \.self) { docType in
                        EnhancedVerificationStep(
                            icon: "person.text.rectangle",
                            title: "Scan \(docType.rawValue)",
                            description: "Use camera to scan your document",
                            isCompleted: false
                        )
                    }
                }
            }
            
            Spacer()
            
            EKYCPrimaryButton(
                title: "Continue Verification",
                isLoading: false,
                action: { Task { await viewModel.continueEnhancedVerification(context: context) } }
            )
        }
        .padding(26)
    }

    // MARK: - Performing Enhanced Verification / Submitting

    @ViewBuilder
    private func performingEnhancedVerificationContent(context: EKYCFlowContext, proxy: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            EKYCProgressIndicator(progress: viewModel.verificationProgress)

            Text("Completing additional checks")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)

            Text("Please wait while we complete the required verification steps.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func submittingContent(proxy: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            EKYCProgressIndicator(progress: 1.0)

            Text("Submitting verification")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)

            Text("Saving your eKYC result securely.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Success State
    
    @ViewBuilder
    private func successContent(result: EKYCResult, proxy: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Verification Complete")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)
            
            Text("Identity verified successfully")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Failure State
    
    @ViewBuilder
    private func failureContent(error: EKYCError, proxy: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Verification Failed")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)
            
            Text(viewModel.errorMessage ?? "An error occurred")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            EKYCPrimaryButton(
                title: "Try Again",
                isLoading: false,
                action: { Task { await viewModel.retryVerification() }}
            )
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

### 7.2 组件样式

```swift
/// 验证方式卡片
struct EKYCMethodCard: View {
    let method: EKYCMethod
    let status: EKYCMethodStatus
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: method.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(titleColor)
                    
                    Text(method.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(subtitleColor)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 选中指示器
                if status == .ready {
                    RadioCircle(isSelected: isSelected)
                } else {
                    StatusBadge(status: status)
                }
            }
            .padding(16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(status != .ready)
    }
    
    // 样式计算属性...
}

/// 增强认证步骤
struct EnhancedVerificationStep: View {
    let icon: String
    let title: String
    let description: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isCompleted ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isCompleted ? "checkmark" : icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isCompleted ? .green : .white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// 进度指示器
struct EKYCProgressIndicator: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
        }
    }
}
```

---

## 8. 测试用例

### 8.1 单元测试

```swift
import Testing
import Foundation

@Suite("EKYCViewModel Tests")
struct EKYCViewModelTests {

    @Test("Initial state is idle")
    func initialState() async {
        let viewModel = makeViewModel()
        #expect(viewModel.state == .idle)
        #expect(viewModel.selectedMethod == .uaepass)
    }

    @Test("Selecting method updates selectedMethod")
    func selectMethod() async {
        let viewModel = makeViewModel()
        viewModel.selectMethod(.deviceBiometrics)
        #expect(viewModel.selectedMethod == .deviceBiometrics)
        #expect(viewModel.state == .preparing(method: .deviceBiometrics, permission: nil))
    }

    @Test("Cannot select unavailable method")
    func selectUnavailableMethod() async {
        let viewModel = makeViewModel(
            methodStatuses: [.uaepass: .ready, .deviceBiometrics: .ready, .documentScan: .comingSoon]
        )
        viewModel.selectMethod(.documentScan)
        #expect(viewModel.selectedMethod == .uaepass)
    }

    @Test("UAE Pass verification succeeds with low risk")
    func uaepassLowRisk() async throws {
        let riskEngine = MockEKYCRiskEngine()
        await riskEngine.setScenario(riskLevel: .low)

        var completedResult: EKYCResult?
        let viewModel = makeViewModel(riskEngine: riskEngine, onComplete: { completedResult = $0 })
        await viewModel.startVerification()

        guard case .success(let result) = viewModel.state else {
            Issue.record("Expected success state")
            return
        }
        #expect(result.method == .uaepass)
        #expect(completedResult != nil)
    }

    @Test("Medium risk stops at enhanced verification before running extra checks")
    func mediumRiskStopsAtEnhancedVerification() async throws {
        let riskEngine = MockEKYCRiskEngine()
        await riskEngine.setScenario(riskLevel: .medium)

        let viewModel = makeViewModel(riskEngine: riskEngine)
        await viewModel.startVerification()

        if case .enhancedRequired(let context) = viewModel.state {
            let requirements = context.riskAssessment.enhancedRequirements
            #expect(requirements.deviceBiometricRequired)
            #expect(!requirements.documentScanRequired)
        } else {
            Issue.record("Expected enhancedRequired state")
        }
    }

    @Test("Regulatory mandatory requires both device biometrics and document")
    func regulatoryMandatory() async throws {
        let riskEngine = MockEKYCRiskEngine()
        await riskEngine.setScenario(riskLevel: .critical, regulatoryMandatory: true)

        let viewModel = makeViewModel(riskEngine: riskEngine)
        await viewModel.startVerification()

        if case .enhancedRequired(let context) = viewModel.state {
            let requirements = context.riskAssessment.enhancedRequirements
            #expect(requirements.isRegulatoryMandatory)
            #expect(requirements.deviceBiometricRequired)
            #expect(requirements.documentScanRequired)
        } else {
            Issue.record("Expected enhancedRequired state")
        }
    }

    // Helper
    private func makeViewModel(
        riskEngine: MockEKYCRiskEngine = MockEKYCRiskEngine(),
        methodStatuses: [EKYCMethod: EKYCMethodStatus]? = nil,
        onComplete: @escaping (EKYCResult) -> Void = { _ in }
    ) -> EKYCViewModel {
        return EKYCViewModel(
            ekycService: MockEKYCService(),
            riskEngine: riskEngine,
            deviceContextEncryptor: MockEKYCDeviceContextEncryptor(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService(),
            onboardingStateStore: OnboardingStateStore(),
            methodStatuses: methodStatuses,
            onBack: {},
            onComplete: onComplete
        )
    }
}

@Suite("EKYCService Tests")
struct EKYCServiceTests {

    @Test("UAE Pass verification returns valid result")
    func uaepassVerification() async throws {
        let service = EKYCService(
            uaePassService: MockUAEPassService(),
            oauthHandler: MockUAEPassOAuthHandler(),
            deviceBiometricService: MockDeviceBiometricService(),
            documentOCRService: MockDocumentOCRService()
        )

        let result = try await service.verifyWithUAEPass()

        #expect(result.method == .uaepass)
        #expect(!result.identityID.isEmpty)
        #expect(result.metadata?.fullName != nil)
    }

    @Test("Device biometrics unavailable is deterministic with mock")
    func deviceBiometricsUnavailable() async throws {
        let service = MockDeviceBiometricService(availability: .notAvailable)
        let availability = await service.checkAvailability()
        #expect(availability == .notAvailable)

        do {
            _ = try await service.authenticate(reason: "Test")
            Issue.record("Expected biometric failure")
        } catch {
            #expect(error is EKYCError)
        }
    }
}
```

> 测试约束：单元测试不直接依赖真实 `LocalAuthentication`、相机、UAE Pass App 或网络。所有权限、设备能力、风险等级都通过 Mock 注入，避免 CI 在不同模拟器或真机上出现不稳定结果。

### 8.2 Mock 服务

```swift
actor MockEKYCService: EKYCServicing {
    func verifyWithUAEPass() async throws -> EKYCResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        return EKYCResult(
            method: .uaepass,
            identityID: "mock-user-id",
            verifiedAt: Date(),
            metadata: EKYCMetadata(
                fullName: "Mock User",
                phoneNumber: "+971501234567",
                documentType: nil,
                documentNumber: nil,
                documentExpiryDate: nil
            ),
            enhancedResults: nil
        )
    }
    
    func verifyWithDeviceBiometrics() async throws -> Bool {
        try await Task.sleep(nanoseconds: 300_000_000)
        return true
    }
    
    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return types.map { type in
            ScannedDocument(
                type: type,
                extractedData: mockData(type),
                scanTimestamp: Date()
            )
        }
    }
    
    func submitVerificationResult(_ result: EKYCResult, assessmentId: String?) async throws -> EKYCSubmitResponse {
        return EKYCSubmitResponse(
            success: true,
            verificationId: "mock-verification-id",
            nextStep: "personalization"
        )
    }
    
    private func mockData(_ type: DocumentType) -> EKYCMetadata {
        switch type {
        case .emiratesID:
            return EKYCMetadata(fullName: "Mock Emirates ID", phoneNumber: nil, documentType: "Emirates ID", documentNumber: "123456", documentExpiryDate: "2030-01-01")
        case .passport:
            return EKYCMetadata(fullName: "Mock Passport", phoneNumber: nil, documentType: "Passport", documentNumber: "A12345", documentExpiryDate: "2028-01-01")
        }
    }
}
```

```swift
actor MockUAEPassOAuthHandler: UAEPassOAuthHandling {
    func performOAuth(config: UAEPassConfig) async throws -> CustSubInfo {
        // Mock code 只存在于测试注入层，生产 EKYCService 不包含硬编码授权码。
        CustSubInfo(userID: "mock-user-id", phoneNumber: "+971501234567", displayName: "Mock User")
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
            extractedData: EKYCMetadata(fullName: "Mock User", phoneNumber: nil, documentType: type.rawValue, documentNumber: "MOCK-123", documentExpiryDate: "2030-01-01"),
            scanTimestamp: Date()
        )
    }

    func scanDocuments(types: [DocumentType]) async throws -> [ScannedDocument] {
        var results: [ScannedDocument] = []
        for type in types {
            results.append(try await scanDocument(type: type))
        }
        return results
    }

    func checkCameraPermission() async -> Bool { true }
    func requestCameraPermission() async -> Bool { true }
}
```

---

## 9. 风险评估与兼容说明

### 9.1 技术风险

| 风险项 | 风险等级 | 缓解措施 |
|--------|----------|----------|
| UAE Pass SDK 版本更新 | 中 | 封装 `UAEPassServicing` 协议，SDK 变化只需修改实现 |
| Device Biometrics 设备不支持 | 低 | `DeviceBiometricAvailability` 状态检查，提供 fallback 路径 |
| VisionKit OCR 精度 | 中 | OCR 结果需后端校验，前端仅做辅助提取 |
| 相机权限拒绝 | 低 | 权限检查 + 用户引导 |
| 网络中断 | 中 | 本地缓存验证状态，支持重试机制 |
| 设备指纹泄露 | 高 | `DeviceContext` 只在本地内存存在，风险请求只提交 `EncryptedPayload` |
| Mock 逻辑进入生产 | 高 | Mock OAuth / Mock Risk / Mock OCR 全部通过依赖注入提供，生产服务不含 `#if DEBUG` 授权码 |

### 9.2 设备兼容性

| 设备特性 | 最低要求 | 说明 |
|----------|----------|------|
| iOS 版本 | iOS 15+ | iOS 16+ 使用 VisionKit DataScanner；iOS 15 使用自定义相机/后端 OCR fallback |
| Device Biometrics | 支持 Face ID 或 Touch ID 的设备 | 不支持或未录入时走 UAE Pass / Document fallback |
| 相机 | 所有 iPhone |证件扫描基础要求 |
| UAE Pass App | 用户需已安装 | 或使用 Safari fallback |

### 9.3 合规场景

| 场景 | 验证要求 | 实现状态 |
|------|----------|----------|
| 新 eSIM 激活 | UAE Pass + 风险引擎评估 | Demo 可测试 |
| Port In | UAE Pass + 风险引擎评估 | Demo 可测试 |
| SIM 补卡 | UAE Pass + Device Biometrics（监管强制） | Demo 可测试 |
| 大额交易 | UAE Pass + 双重认证 | Demo 可测试 |

### 9.4 网络环境

| 网络状态 | 处理策略 |
|----------|----------|
| WiFi/4G/5G | 正常流程 |
| 3G/弱网 | 增加超时容忍，提供手动刷新 |
| 无网络 | 显示错误，缓存状态供恢复 |

### 9.5 边界场景

| 场景 | 处理策略 |
|------|----------|
| App 切换后台后恢复 | 通过 `EKYCViewState` 关联值恢复当前上下文；OAuth session 由 `UAEPassOAuthHandling` 内部恢复或取消 |
| UAE Pass App 未安装 | 真实 OAuth Handler 自动 fallback 到 Safari / `ASWebAuthenticationSession` |
| 证件过期 | OCR 提取 `documentExpiryDate` 后进行本地预校验，并由后端最终判定 |
| 多设备同时验证 | 后端以 `assessmentId` / `verificationId` 做幂等与冲突处理，前端展示冲突错误并允许重新开始 |
| 网络状态变化 | 每个远程阶段设置超时、重试和取消策略；失败后保留可恢复上下文 |
| 连续失败 | ViewModel 记录失败次数，达到阈值后锁定当前方式并引导使用 fallback 或人工审核 |

---

## 10. 后续扩展计划

### 10.1 第二阶段：拆分子页面

当交互复杂度增加：

- `EKYCUAEPassView.swift` — UAE Pass OAuth 流程详情
- `EKYCDeviceBiometricView.swift` — Device Biometrics 执行界面
- `EKYCDocumentScanView.swift` — VisionKit 扫描界面

### 10.2 第三阶段：真实后端集成

- 替换 `MockEKYCRiskEngine` 为 `RemoteEKYCRiskEngine`
- 接入真实 OCR 校验 API
- 接入活体检测 API（如需要）

---

## 附录：API 接口定义（后端对接）

### Risk Assessment API

```http
POST /api/v1/ekyc/risk-assessment
Content-Type: application/json

Request:
{
  "primary_verification_result": {
    "method": "uaepass",
    "identity_id": "user-123",
    "verified_at": "2026-05-10T12:00:00Z",
    "metadata": {
      "full_name": "Ahmed Al-Rashid",
      "phone_number": "+971501234567"
    }
  },
  "encrypted_device_context": {
    "algorithm": "rsa-pkcs1-v1_5",
    "key_id": "registration-public-key-v1",
    "ciphertext": "BASE64_RSA_CIPHERTEXT"
  },
  "network_info": {
    "connection_type": "wifi",
    "carrier_name": "Etisalat"
  },
  "business_scenario": "newESIMActivation"
}

Response:
{
  "risk_level": "medium",
  "enhanced_requirements": {
    "device_biometric_required": true,
    "face_liveness_required": false,
    "document_scan_required": false,
    "document_types": [],
    "is_regulatory_mandatory": false
  },
  "assessment_id": "risk-123",
  "assessed_at": "2026-05-10T12:01:00Z"
}
```

### Verification Submit API

```http
POST /api/v1/ekyc/submit
Content-Type: application/json

Request:
{
  "result": {
    "method": "uaepass",
    "identity_id": "user-123",
    "verified_at": "2026-05-10T12:00:00Z",
    "metadata": {...},
    "enhanced_results": {
      "device_biometric_passed": true,
      "face_liveness_passed": false,
      "document_scan_passed": false,
      "scanned_documents": []
    }
  },
  "assessment_id": "risk-123"
}

Response:
{
  "success": true,
  "verification_id": "ekyc-456",
  "next_step": "personalization"
}
```
