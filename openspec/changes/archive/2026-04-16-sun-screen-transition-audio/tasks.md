## 1. 音频文件重命名

- [x] 1.1 将 `WeatherData/Audio/candidate_001.wav` 重命名为 `sun-detail-enter.wav`
- [x] 1.2 将 `WeatherData/Audio/candidate_002.wav` 重命名为 `sun-detail-exit.wav`

## 2. WeatherAudioPlayer 扩展

- [x] 2.1 在 `WeatherSunTapAudioRuntimeCore.audioURL(name:bundle:fileManager:)` 的格式搜索列表 `["m4a", "mp3"]` 中追加 `"wav"`，顺序改为 `["m4a", "mp3", "wav"]`
- [x] 2.2 新增 `playSunDetailEnter()` 方法，调用 `playOneshot("sun-detail-enter", volume: 1.0)`
- [x] 2.3 新增 `playSunDetailExit()` 方法，调用 `playOneshot("sun-detail-exit", volume: 1.0)`

## 3. WeatherMainView 调用点替换

- [x] 3.1 在 `beginSunDetailPresentation()` 末尾，将 `playDetailedEnter()` 替换为 `playSunDetailEnter()`
- [x] 3.2 在 `exitSunDetail()` 中，将 `playShapeTap()` 替换为 `playSunDetailExit()`
- [x] 3.3 确认 `onAppear` 中的 `playDetailedEnter()` 调用保持不变

## 4. 验证

- [x] 4.1 构建项目，确认无编译错误
- [x] 4.2 运行时验证：点击太阳进入第二屏，播放 `sun-detail-enter.wav`
- [x] 4.3 运行时验证：点击空白处退出第二屏，播放 `sun-detail-exit.wav`
- [x] 4.4 确认首次进入天气模块（`onAppear`）仍播放原有 `menu-open-1` 音效
