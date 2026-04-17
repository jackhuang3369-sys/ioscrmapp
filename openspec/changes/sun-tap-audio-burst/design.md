# Design: Sun Tap Audio Burst

## Context

现有 `WeatherAudioPlayer` 使用单个全局线程（main thread）直接操作 `oneshotPool` 字典。在快速多次点击或高并发场景下，可能发生：
1. Pool 字典的并发读写冲突
2. AVAudioPlayer 实例的非线程安全访问
3. 线程崩溃（尤其在快速滑动场景已验证的问题）

设计目标：**每次太阳点击时，随机播放 sfx_001-007 之一，音量根据连续点击次数递减，全程多线程安全**。

## Goals / Non-Goals

**Goals:**
- 在 WeatherAudioPlayer 中引入串行队列 `audioQueue`，所有 oneshotPool 操作均通过此队列执行
- 实现 `playSunTapBurst()` 方法，随机从 7 个 sfx 文件中选一个
- 连续点击检测与动态音量调整：计数器在 500ms 无新调用后 reset
- 在 WeatherSceneView 的 tap 检测中即时触发音效（无额外 delay，与视觉动画同步）
- 最小化 smoke 覆盖，验证计数器递减、音量映射、pool 状态

**Non-Goals:**
- 不修改场景动画参数、节点结构、或其他 UI 系统
- 不引入新的 AudioEngine 或 AVKit API，保持 AVAudioPlayer 体系
- 不修改现有的音效播放方法（如 playShapeTap 等）

## Decisions

### 1. 串行队列管理

```swift
private let audioQueue = DispatchQueue(
  label: "com.weather.audio.burst",
  qos: .default
)
```

- **为什么不用 .userInteractive**：音效播放不是 UI 渲染，.default 足够，避免争用 CPU 时间
- **为什么不用 .background**：500ms+ 延迟对音效播放可感知，.default 保证响应
- **Pool 操作全部 dispatch**：`audioQueue.async { ... }` 包装所有 oneshotPool 读写

### 2. 随机选择与计数器

```swift
// 伪代码
private var sunTapClickCount: Int = 0
private var sunTapLastCallTime: TimeInterval = 0

func playSunTapBurst() {
  audioQueue.async { [weak self] in
    let now = CACurrentMediaTime()
    if now - self.sunTapLastCallTime > 0.5 {
      self.sunTapClickCount = 0
    }
    self.sunTapClickCount += 1
    self.sunTapLastCallTime = now
    
    let index = Int.random(in: 1...7)
    let sfxName = "sfx_00\(index)"
    let volume = self.volume(forClickCount: self.sunTapClickCount)
    self.playSunTapOneshot(sfxName, volume: volume)
  }
}

func volume(forClickCount count: Int) -> Float {
  switch count {
    case 1...2: return 0.36  // 明亮
    case 3...4: return 0.28  // 稍弱
    default:    return 0.20  // 更弱（防疲劳）
  }
}
```

**替代方案（DispatchSourceTimer）**：定期自动 reset 计数器，但权衡下来单线程队列内业务逻辑判断足够，无需额外定时器。

### 2.1 音频格式 fallback（m4a + mp3）

Sun Tap 音效文件为 mp3，因此 `audioURL(_:)` 需要保持既有 m4a 优先，同时补充 mp3 fallback。

```swift
private func audioURL(_ name: String) -> URL? {
  // 1) direct path m4a
  // 2) bundle m4a
  // 3) direct path mp3
  // 4) bundle mp3
}
```

这样既不破坏现有 m4a 资源，也能保证 sfx_001-007 可被正确加载。

### 3. 播放位点：选项 A（Coordinator 层）

在 `WeatherSceneView.Coordinator.handleTap()` 检测到太阳点击时，立即触发：

```swift
@objc func handleTap(_ gesture: UITapGestureRecognizer) {
  guard gesture.state == .ended,
        let scnView = gesture.view as? SCNView else { return }

  let location = gesture.location(in: scnView)
  let hits = scnView.hitTest(location, options: [...])
  if hits.contains(where: { isInteractiveNode($0.node) && !isTemperatureNode($0.node) }) {
    // 🎵 立即播放音效，与视觉同步
    WeatherAudioPlayer.shared.playSunTapBurst()
    onSunTap?()
  } else {
    onBackgroundTap?()
  }
}
```

优势：
- 点击检测完成的同一时刻触发声效，最小延迟
- 避免在 SceneManager 引入 UI 层依赖，职责分离清晰
- 与视觉爆发动画时间轴对齐

### 4. Pool 管理与并发限制

```swift
```swift
private var sunTapPlayer: AVAudioPlayer?

private func playSunTapOneshot(_ name: String, volume: Float) {
  // 在 audioQueue 内执行
  // 若 sunTapPlayer 正在播放，则停止并重置（后到先播）
  // 切换到新的 sfx URL，prepareToPlay 后立即播放
}
```
```
使用“全局单实例通道（sunTapPlayer）”而非“按文件分池 + 每文件并发=1”的原因：
- 按文件分池会允许不同文件并行播放，无法满足“任意时刻只播一个”
- 单实例可确保快速点击时仍然稳定，不会产生多轨叠加
- 语义与用户目标完全一致：一次点击对应一个当前声效
- 符合用户预期（一次点击→一个声音）

### 5. 音量映射精度

| 连续次数 | 音量 | 感知 |
|---------|------|------|
| 1-2     | 0.36 | 明亮（基础） |
| 3-4     | 0.28 | 稍弱（-22%） |
| 5+      | 0.20 | 更弱（-44%） |

参考现有音量：0.35(tap)、0.40(open)、0.26(spin)，设计范围在 0.20-0.36 之间，易感知差异。

## Risks / Trade-offs

- **[后到先播策略]** 快速连点会截断上一条尚未播完的 sfx → **接受**，优先保证交互即时反馈与音轨清晰度
- **[500ms reset 时间]** 如果用户在 450ms 时再点一次，仍会被视为连续 → **符合预期**，这正是"连续点击"的定义
- **[播放失败 silent fail]** 若 sfx 文件损坏或网络加载失败 → **接受**，避免 UI 崩溃；可后续加日志监测
- **[音量值硬编码]** 未来若需调整，需修改代码 → **可接受**；如需热更新可后续引入配置系统

## Open Questions

无。所有设计决策已澄清。
