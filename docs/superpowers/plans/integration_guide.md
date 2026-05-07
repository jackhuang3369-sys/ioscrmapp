# AI 意图识别系统集成指南

## 1. 添加文件到 Xcode 项目

### 1.1 需要添加的新文件

**Models 目录**：
```
ioscrmapp/Modules/AI/Models/
├── IntentModels.swift (新增)
└── IntentClassificationModels.swift (新增)
```

**Services 目录**：
```
ioscrmapp/Services/
└── IntentRecognitionService.swift (新增)
```

**Utilities 目录**：
```
ioscrmapp/Utilities/
├── LocalIntentMatcher.swift (新增)
└── IntentConfidenceCalculator.swift (新增)
```

**Views 目录**：
```
ioscrmapp/Modules/AI/Views/
└── IntentFeedbackView.swift (新增)
```

**Tests 目录**：
```
ioscrmapp/Tests/AIModelsTests/
├── IntentModelsTests.swift (新增)
├── IntentClassificationModelsTests.swift (新增)
├── IntentRecognitionIntegrationTests.swift (新增)
├── IntentRecognitionPerformanceTests.swift (新增)
└── TEST_REPORT.md (新增)
```

### 1.2 Xcode 添加文件步骤

1. **打开 Xcode 项目**：
   ```bash
   open ioscrmapp/ioscrmapp.xcodeproj
   ```

2. **添加源文件**：
   - 在 Project Navigator 中右键点击目标文件夹
   - 选择 "Add Files to 'ioscrmapp'..."
   - 导航到文件位置并选择文件
   - 确保勾选 "Copy items if needed"（如果文件不在项目目录中）
   - 确保勾选目标 Target（ioscrmapp-Develop、ioscrmapp-Production）

3. **添加测试文件**：
   - 确保测试文件添加到 Test Target
   - 如果没有 Test Target，需要创建一个新的 Test Target

### 1.3 验证文件添加

在 Xcode 中编译项目：
```bash
xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop clean build
```

---

## 2. 配置 Swift Testing 框架

### 2.1 Swift Testing 配置步骤

1. **检查项目 Swift 版本**：
   - 确保 Swift 5.9+（Swift Testing 需要）
   - 在 Build Settings 中验证 Swift Language Version

2. **添加 Swift Testing 包依赖**（如果需要）：
   ```swift
   // Package.swift（如果使用 SPM）
   dependencies: [
       .package(url: "https://github.com/apple/swift-testing", from: "0.1.0")
   ]
   ```

3. **导入 Swift Testing**：
   ```swift
   import Testing
   ```

### 2.2 替代方案：使用 XCTest

如果项目不支持 Swift Testing，可以改用 XCTest：

**转换测试文件示例**：

```swift
// IntentModelsTests.swift (XCTest 版本)
import XCTest
@testable import ioscrmapp

final class IntentModelsTests: XCTestCase {
    func testUserIntentTypeSerialization() throws {
        for intentType in UserIntentType.allCases {
            let encoded = try JSONEncoder().encode(intentType)
            let decoded = try JSONDecoder().decode(UserIntentType.self, from: encoded)
            
            XCTAssertEqual(decoded, intentType, "Intent type should serialize correctly")
        }
    }
    
    func testUserIntentTypeDisplayNames() throws {
        let intentType = UserIntentType.balanceInquiry
        
        XCTAssertEqual(intentType.displayName(for: .english), "Balance Inquiry")
        XCTAssertEqual(intentType.displayName(for: .simplifiedChinese), "查询余额")
        XCTAssertEqual(intentType.displayName(for: .arabic), "استعلام الرصيد")
    }
}
```

---

## 3. 集成新系统到现有代码

### 3.1 更新 AppServices.swift

在 `ioscrmapp/Services/AppServices.swift` 中添加意图识别服务：

```swift
struct AppServices {
    let offersService: any OffersServicing
    let aiChatService: any AIChatServicing
    let intentRecognitionService: any IntentRecognitionServicing // 新增

    init() {
        offersService = DefaultOffersService()
        aiChatService = MockAIChatService() // 或真实服务
        
        // 新增：初始化意图识别服务
        intentRecognitionService = DefaultIntentRecognitionService(
            aiChatService: aiChatService
        )
    }
}
```

### 3.2 更新 AIAssistantEntryView.swift

在创建 AIChatViewModel 时注入意图识别服务：

```swift
// ioscrmapp/Modules/AI/Views/AIAssistantEntryView.swift

let viewModel = AIChatViewModel(
    custSubInfo: custSubInfo,
    language: language,
    aiChatService: aiChatService,
    offersService: offersService,
    intentRecognitionService: AppServices().intentRecognitionService // 新增
)
```

---

## 4. 运行测试验证

### 4.1 运行单元测试

```bash
# 使用 Xcode 运行测试
xcodebuild test -project ioscrmapp.xcodeproj \
  -scheme ioscrmapp-Develop \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# 或使用 swift test（如果配置 SPM）
swift test
```

### 4.2 验证核心功能

**手动验证步骤**：

1. **启动 App**：
   ```bash
   xcodebuild -project ioscrmapp.xcodeproj \
     -scheme ioscrmapp-Develop \
     -destination 'platform=iOS Simulator,name=iPhone 15' \
     run
   ```

2. **测试意图识别**：
   - 打开 AI Assistant 入口
   - 输入测试文本："How can I check my balance?"
   - 验证识别结果和导航行为

3. **测试置信度分级**：
   - 输入明确意图："check balance"（高置信度）
   - 输入模糊意图："I need help"（低置信度）
   - 验证确认对话框显示

---

## 5. 常见问题排查

### 5.1 编译错误

**问题**：Cannot find type 'IntentRecognitionResult' in scope

**解决方案**：
1. 确保文件已添加到 Xcode 项目
2. 检查 Target Membership（文件应属于正确的 Target）
3. 检查 Build Phases → Compile Sources

### 5.2 测试框架错误

**问题**：No such module 'Testing'

**解决方案**：
1. 配置 Swift Testing 框架
2. 或改用 XCTest（参考转换示例）
3. 确保测试文件属于 Test Target

### 5.3 导航不工作

**问题**：意图识别成功但未导航

**解决方案**：
1. 检查 `onNavigate` 回调是否正确传递
2. 检查导航目标是否正确映射
3. 添加日志追踪导航调用

---

## 6. 下一步优化方向

### 6.1 真实 AI 服务集成

**配置真实 AI 服务端点**：

```swift
// IntentRecognitionService.swift
let configuration = AIChatConfiguration.current

// 真实 AI 服务调用（替换 Mock）
let realService = DefaultAIChatService(configuration: configuration)
let intentService = DefaultIntentRecognitionService(aiChatService: realService)
```

### 6.2 关键词列表优化

**扩展关键词覆盖**：

```swift
// LocalIntentMatcher.swift
mappings[.balanceInquiry] = [
    .english: [
        "check my balance",
        "view my balance",
        "how much credit",      // 新增
        "remaining balance",    // 新增
        "current balance"       // 新增
    ],
    // ...
]
```

### 6.3 性能监控

**添加识别耗时日志**：

```swift
import OSLog

private let logger = Logger(subsystem: "com.inspur.ioscrmapp", category: "IntentRecognition")

func recognizeIntent(...) async throws -> IntentRecognitionResult {
    let startTime = Date()
    
    let result = try await service.recognizeIntent(...)
    
    let elapsed = Date().timeIntervalSince(startTime) * 1000
    logger.info("Intent recognition completed in \(elapsed)ms")
    
    return result
}
```

---

## 7. 配置检查清单

### 7.1 文件添加检查
- [ ] IntentModels.swift 添加到 Models 目录
- [ ] IntentClassificationModels.swift 添加到 Models 目录
- [ ] IntentRecognitionService.swift 添加到 Services 目录
- [ ] LocalIntentMatcher.swift 添加到 Utilities 目录
- [ ] IntentConfidenceCalculator.swift 添加到 Utilities 目录
- [ ] IntentFeedbackView.swift 添加到 Views 目录

### 7.2 Target Membership 检查
- [ ] 所有源文件属于 ioscrmapp Target
- [ ] 测试文件属于 Test Target
- [ ] 文件出现在 Build Phases → Compile Sources

### 7.3 编译验证
- [ ] 项目编译无错误
- [ ] 所有类型引用正确
- [ ] 模块导入正确

### 7.4 测试验证
- [ ] 单元测试可运行
- [ ] 集成测试可运行
- [ ] 性能测试可运行

---

## 8. 快速集成脚本（参考）

```bash
#!/bin/bash
# quick_integrate.sh - 快速集成意图识别系统

# 1. 检查文件是否存在
echo "Checking files..."
required_files=(
    "ioscrmapp/Modules/AI/Models/IntentModels.swift"
    "ioscrmapp/Services/IntentRecognitionService.swift"
    "ioscrmapp/Utilities/LocalIntentMatcher.swift"
    "ioscrmapp/Modules/AI/Views/IntentFeedbackView.swift"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing file: $file"
        exit 1
    fi
    echo "✅ Found: $file"
done

# 2. 验证文件内容
echo "Validating file structure..."
grep -q "UserIntentType" ioscrmapp/Modules/AI/Models/IntentModels.swift
grep -q "IntentRecognitionServicing" ioscrmapp/Services/IntentRecognitionService.swift

echo "✅ All files validated"

# 3. 提示用户下一步操作
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode: open ioscrmapp/ioscrmapp.xcodeproj"
echo "2. Add new files to project (see guide)"
echo "3. Build and test"
echo ""
echo "🎉 Integration ready!"
```

---

**配置指南完成日期**：2026-05-02
**版本**：v1.0