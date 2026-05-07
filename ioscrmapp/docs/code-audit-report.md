# ioscrmapp 代码深度审计报告

> 审计日期：2026-04-24
> 审计范围：ioscrmapp 全项目（SwiftUI + MVVM + SceneKit）

---

## 一、值得学习的模式 (Outstanding Patterns)

### 1.1 设计令牌三层架构

项目构建了业界标准的 **Primitive → Semantic → Runtime** 三层令牌体系：

- **Primitives 层** (`DesignSystem/Tokens/Primitives/`): DUColorPrimitives、DUTypographyPrimitives、DUSpacing、DURadius、DUElevation、DUMotion，提供原子级基础值
- **Semantics 层** (`DesignSystem/Tokens/Semantics/`): DUColorTokens、DUTypographyTokens、DUComponentTokens，将原始值映射为语义意图（如 Text.primary、Status.error）
- **Runtime 层** (`DesignSystem/Tokens/Runtime/`): DUTheme、DUThemeMode、DUThemeEnvironment，运行时解析当前配色方案并注入 SwiftUI Environment

**核心优势**：`DUColorToken` 同时持有 light/dark 两个 Color，通过 `resolve(for: colorScheme)` 单一函数完成深浅色切换，消除大量 if/else 分支。`DUTheme` 将 colors + typography + components 打包为值对象，通过 `@Environment(\.duTheme)` 在视图树中传递。

**关键文件**：
- `DesignSystem/Tokens/Primitives/DUColorPrimitives.swift`
- `DesignSystem/Tokens/Semantics/DUColorTokens.swift`
- `DesignSystem/Tokens/Runtime/DUTheme.swift`
- `DesignSystem/Tokens/Runtime/DUThemeEnvironment.swift`

### 1.2 协议驱动服务 + Mock/Remote 双实现

每个业务服务遵循统一范式：

```swift
protocol XxxServicing: Sendable { /* async throws 方法签名 */ }
actor MockXxxService: XxxServicing { /* 本地假数据 + Task.sleep 模拟延迟 */ }
struct RemoteXxxService: XxxServicing { /* HTTPClient 调用后端 API */ }
```

`AppServices` 容器根据 `AppServiceConfiguration.mode` 在 `.mock` 和 `.remote` 之间切换，所有 ViewModel 和 View 只依赖协议类型 `any XxxServicing`，完全解耦具体实现。Mock 使用 actor 隔离，满足 Sendable 要求。

**关键文件**：
- `Services/AppServices.swift`
- `Services/AuthService.swift`
- `Services/MallService.swift`

### 1.3 语义化字体系统

`.du()` 系列函数提供两种入口：
- **语义风格**：`Font.du(.headlineStrong)` — 映射到预设大小+粗细组合
- **数值定制**：`Font.du(17, weight: .bold)` — 当语义令牌无法覆盖时回退

`DUTypographyToken` 封装 size + weight，`DUTypographyTokens.Resolved` 提供从 micro(9pt) 到 resultDisplay(56pt) 共 30+ 语义令牌。

**关键文件**：`DesignSystem/Tokens/Semantics/DUTypographyTokens.swift`

### 1.4 类型安全本地化

`LocalizedTextValue` 枚举只用两个 case 即实现编译期类型安全：

```swift
enum LocalizedTextValue: Equatable, Sendable {
    case localized(String, [String])  // key + 插值参数
    case literal(String)              // 运行时动态文本
}
```

所有 Service Error 通过 `var textValue: LocalizedTextValue` 暴露用户可见文案。`AppLanguage` 同时处理 locale 标识、布局方向（RTL for Arabic）和原生名称。

**关键文件**：
- `Core/Localization/LocalizedTextValue.swift`
- `Core/Localization/AppLanguage.swift`

### 1.5 Keychain 令牌存储 + 自动刷新

`KeychainAuthTokenStore` 使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 级别存取。`AuthRefreshCoordinator` 防并发刷新 — 多个请求同时发现 token 过期只触发一次刷新，其他请求等待复用新 token。

**关键文件**：
- `Core/Storage/SessionKeychainStores.swift`
- `Core/Networking/NetworkContextBuilder.swift`

### 1.6 SceneKit 场景常量提取

`SceneNode` 枚举集中管理所有 SCNNode.name 字符串，`WeatherSunBurstCore` 将光线爆发调参数值封装为 static 常量，避免字符串拼写错误。

**关键文件**：
- `Modules/Weather/SceneKit/SceneConstants.swift`
- `Modules/Weather/SceneKit/WeatherSunBurstCore.swift`

### 1.7 环境配置编译时/运行时双重覆盖

`AppEnvironment` 通过 `#if APP_PACKAGE_DEVELOP` 编译标志确定默认环境，同时支持 `IOSCRMAPP_ENVIRONMENT` / `IOSCRMAPP_SERVICE_MODE` / `IOSCRMAPP_SERVER_URL` 环境变量运行时覆盖。同一个 .ipa 通过 Xcode Scheme 环境变量注入即可切换后端地址，无需重编译。

**关键文件**：`Core/Config/AppEnvironment.swift`

### 1.8 令牌驱动组件样式

每个 DU 组件（DUButton、DUTextField、DUSectionCard 等）通过 `@Environment(\.duTheme)` 读取令牌，样式修饰符以 ViewModifier 封装（`duCardStyle()`、`duFieldShell(isError:)`），一行代码获得完整令牌化外观。

**关键文件**：
- `Common/Components/Buttons/DUButton.swift`
- `Common/Components/Fields/DUTextField.swift`
- `DesignSystem/Styles/DUCardStyle.swift`
- `DesignSystem/Styles/DUFieldStyle.swift`

---

## 二、需要改进的部分

### 2.1 上帝文件 — 职责过重的大型文件

| 文件 | 行数 | 核心问题 | 修复策略 |
|------|------|---------|---------|
| `Services/MallService.swift` | 3344 | MallServicing 协议 14 个方法，Mock + Remote + MockData + 多个 Request/Response 全在一文件 | 拆为 MallHomeServicing/MallSearchServicing/MallCartServicing/MallDetailServicing 四个子协议，各配独立文件 |
| `Modules/AI/Views/AIChatView.swift` | 3159 | 完整聊天 UI + 语音输入 + 3D 动画 + 消息解析 + 键盘适配 + 导航 | 提取 AIChatComposerView/AIChatMessageListView/AIChat3DCoreView |
| `Modules/Weather/SceneKit/WeatherSceneManager.swift` | 2860 | 主场景构建 + 太阳爆发 + 温度3D文字 + 详情维度 + 过渡动画 + 手势 + 音效 | 提取 WeatherSunBurstAnimator/WeatherTemperatureBuilder/WeatherDetailDimensionBuilder/WeatherTransitionController |
| `Modules/Home/Views/HomeView.swift` | 2696 | 14 个 @State + 10+ fullScreenCover + Tab 导航 + 全局服务注入 | 提取每个 Tab 为独立 View，创建 HomeNavigationCoordinator |

### 2.2 @State 属性过多

| 文件 | @State 数 | 问题 | 修复策略 |
|------|----------|------|---------|
| `HomeView.swift` | 14 | 14 个布尔/枚举追踪 6+ fullScreenCover + Tab + 签出 + 折叠 | 创建 `HomeNavigationState: ObservableObject` 集中管理路由 |
| `AIChatView.swift` | 12 | 动画状态、语音模式、浮动消息、键盘追踪 | 将 composerMode/isVoiceListening 移入 ViewModel，提取 AIChatAnimationState |
| `WeatherMainView.swift` | 10 | 场景加载、时间轴选择、太阳详情过渡、气泡状态 | 提取 WeatherDetailNavigationState |

### 2.3 胖协议 — 方法过多的服务协议

| 协议 | 方法数 | 修复策略 |
|------|--------|---------|
| `MallServicing` | 14 | 拆为 MallHomeServicing(3)/MallSearchServicing(4)/MallCartServicing(6)/MallDetailServicing(1) |
| `AuthServicing` | 10 | 拆为 AuthLoginServicing(3)/AuthRegistrationServicing(4)/AuthPasswordRecoveryServicing(3) |
| `BillingServicing` | 8+ | 拆为 BillingQueryServicing + BillingPaymentServicing |

### 2.4 代码重复 — LegacyWeatherSunDetailOverlay

`WeatherMainView.swift:563` 的 `LegacyWeatherSunDetailOverlay` 与 `WeatherSunDetailViews.swift` 的 `WeatherSunDetailOverlay` 高度重复。删除 Legacy 版本或通过枚举参数（`detailStyle: .legacy / .observed`）统一。

### 2.5 魔法数字

`WeatherSceneManager.swift` 中散布大量未命名数值字面量：光源强度 1380/1320、动画时长 0.42、3D 坐标 4.40/-2.4/24.9 等。扩展 `SceneConstants.swift` 中 `ScenePosition`/`SceneLighting`/`SceneAnimation` 枚举统一管理。

### 2.6 DUMotion 令牌不完整

当前只有 3 个 easeInOut 时长，缺少项目中大量使用的 spring 曲线。建议扩展：

```swift
enum DUMotion {
    enum Spring {
        static let gentle = Animation.spring(response: 0.60, dampingFraction: 0.80)
        static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.70)
        static let bouncy = Animation.spring(response: 0.46, dampingFraction: 0.55)
    }
}
```

### 2.7 冒烟测试重复定义协议

`SmokeTests/MallPagingSmokeTests.swift` 重新声明了 CustSubInfo/MallServicing 等类型，应通过 `@testable import` 引入，避免协议变更时测试不编译失败。

---

## 三、技术债务

### 3.1 测试覆盖率几乎为零 [Critical]

**现状**：仅 6 个冒烟测试文件，只验证 Mock 服务基本调用链，不测试业务逻辑、边界条件或 UI 交互。冒烟测试甚至重复定义了协议类型。

**风险**：
- MVVM 架构的可测试性优势完全未兑现
- 任何重构无法保证行为不变
- MockService 和 RemoteService 行为分歧无法被检测

**修复优先级**：
1. 先为所有 ViewModel 编写单元测试（最易测、ROI 最高）
2. 为 Service 层 Mock/Remote 编写一致性测试
3. 对核心流程（登录→首页加载→账单支付）编写集成测试

### 3.2 缺少证书锁定 [Security]

CRM 应用仅依赖 ATS，无 certificate pinning。应在 `HTTPClient` 的 URLSessionDelegate 中对生产 API 域名验证证书公钥哈希。

### 3.3 无 CI/CD 配置 [Infrastructure]

无自动化质量门禁。创建 `.github/workflows/ci.yml` 配置编译 + 冒烟测试 + SwiftLint。

### 3.4 无离线 CRM 数据策略 [Data]

仅缓存静态资源，业务数据无离线持久化。引入 SwiftData/Core Data 缓存关键模型，网络失败回退本地数据源。

### 3.5 HomeView 服务注入参数爆炸 [Architecture]

HomeView.init 接收 13 个服务协议参数。创建 `HomeServiceContainer` 封装所有服务，或通过 Environment 注入 AppServices 子集。

---

## 四、推荐创建的 Skill

| Skill | 描述 | 优先级 |
|-------|------|--------|
| `swiftui-scenekit-patterns` | SwiftUI + SceneKit 深度集成实战模式 | 高 |
| `crm-mobile-architecture` | MVVM + 协议导向 + 功能模块的企业级 CRM 架构 | 高 |
| `du-design-system` | 令牌驱动的 SwiftUI 设计系统 | 高 |
| `swiftui-localization-i18n` | 类型安全本地化 + RTL/阿拉伯语支持 | 中 |
| `swift-networking-layer` | async/await + URLSession 网络层架构 | 中 |
