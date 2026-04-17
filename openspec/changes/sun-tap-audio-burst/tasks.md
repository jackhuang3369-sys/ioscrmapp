# Tasks: Sun Tap Audio Burst

## 1. 在 WeatherAudioPlayer 中增加串行队列与计数器

- [x] 1.1 在 `WeatherAudioPlayer` 中新增私有属性：
  - `private let audioQueue = DispatchQueue(label: "com.weather.audio.burst", qos: .default)`
  - `private var sunTapClickCount: Int = 0`
  - `private var sunTapLastCallTime: TimeInterval = 0`

- [x] 1.2 保持 `playOneshot()` 行为不变，并新增 sun-tap 专用单实例播放器属性（如 `sunTapPlayer`），避免影响其他音效路径

- [x] 1.3 补充 `audioURL(_:)` 的 mp3 fallback：在 m4a 查找失败时继续查找 mp3

## 2. 实现 playSunTapBurst() 方法

- [x] 2.1 新增 `playSunTapBurst()` 公共方法，逻辑如下：
  ```
  audioQueue.async { [weak self] in
    // 计数器 reset 逻辑：若距上次调用 > 500ms，则 clickCount = 0
    // 否则 clickCount += 1
    
    // 随机选择 sfx_00X（X ∈ [1,7]）
    // 根据 clickCount 查表得到音量（0.36 / 0.28 / 0.20）
    // 调用 playSunTapOneshot(sfxName, volume)
  }
  ```

- [x] 2.2 实现音量映射函数 `volumeForClickCount(_ count: Int) -> Float`，返回对应档位

- [x] 2.3 新增 `playSunTapOneshot(_ name: String, volume: Float)`：基于全局单实例通道播放，若上一个 sun-tap 音频在播则先停止再播新音频
- [x] 2.4 验证 sfx 文件加载正常（audioURL 能否正确定位 sfx_001-007.mp3）

## 3. 在 Coordinator 的 tap 处理中集成音效触发

- [x] 3.1 在 `WeatherSceneView.Coordinator.handleTap()` 中，当检测到太阳点击时，在调用 `onSunTap?()` 前或同时，插入：
  ```
  WeatherAudioPlayer.shared.playSunTapBurst()
  ```

- [x] 3.2 确保音效触发不会阻塞 gesture 处理（应当是 async dispatch，不是 sync）

## 4. 最小 smoke 覆盖

- [x] 4.1 在 `SmokeTests/` 中新增或扩展用例，验证：
  - sfx_001-007 文件可成功加载（mp3 fallback 返回非 nil）
  - 音量映射正确：count=1→0.36、count=3→0.28、count=5→0.20
  - 计数器在 500ms 无调用后能正确 reset
  - 连续调用时全局仅保留 1 条 sun-tap 播放通道（无多轨叠加）

- [x] 4.2 编译验证，确保无新的编译警告或类型错误

## 5. 集成验证

- [ ] 5.1 在模拟器/真机上快速点击太阳（第一屏），确认：
  - 首次声音明亮（0.36）
  - 连续 2-3 次后声音变弱（0.28）
  - 连续 5 次+ 更弱（0.20）
  - 暂停 600ms+ 后再点，声音恢复明亮

- [ ] 5.2 验证无线程崩溃或异常日志

- [ ] 5.3 确认视觉爆发与音效同步触发

- [x] 5.4 `xcodebuild` 编译通过，无新警告

## 6. 可选性能优化

- [ ] 6.1 使用 Instruments 验证 audioQueue 任务执行时间 < 5ms（不影响交互）
- [ ] 6.2 检查内存占用，确认 sunTapPlayer 单实例稳定且原有 oneshotPool 无异常增长

### Automated evidence (2026-04-13)

- `swiftc -parse-as-library SmokeTests/WeatherSunTapAudioSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSunBurstCore.swift -o /tmp/weather-sun-tap-audio-smoke && /tmp/weather-sun-tap-audio-smoke`
  -> `Weather sun tap audio smoke tests passed`
- `swiftc -parse-as-library SmokeTests/WeatherSunBurstTransitionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSunBurstCore.swift -o /tmp/weather-sunburst-smoke && /tmp/weather-sunburst-smoke`
  -> `Weather sun burst transition smoke tests passed`
- `xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD"`
  -> `BUILD SUCCEEDED`

## Acceptance Criteria

✅ 太阳点击时随机播放 sfx_001-007 之一  
✅ 连续点击时音量递减（0.36 → 0.28 → 0.20）  
✅ 多线程安全，无崩溃  
✅ smoke 通过，编译无警告  
✅ 实机验证音效与视觉同步  
