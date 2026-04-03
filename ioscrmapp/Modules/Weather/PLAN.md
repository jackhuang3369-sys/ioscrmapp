# Not Boring Weather — Demo Rebuild Plan
> Target: iOS Swift + SceneKit | 2 Pages | Mock Data | English Only

---

## 0. Overview

Rebuild a **visual-only demo** of Not Boring Weather referencing the original IPA assets.  
No live data. No localization. No in-app purchase logic.

### Two Pages

| Page | Description |
|------|-------------|
| **A · Main** | Full-screen 3D SceneKit scene for current weather + city/temp overlay + bottom 7-day forecast strip |
| **B · Detail** | Tap into current day → card grid breakdown: Temperature, Feels Like, Wind, Precipitation, Humidity, UV Index, Visibility, Sunrise/Sunset |

### Navigation Flow

```
Page A (Main)
  └─ tap anywhere on 3D scene or "Today" card
       └─► Page B (Detail)  ←  swipe-down / back to dismiss
```

---

## 1. Asset Inventory — What Exists vs What We Build

### 1.1 Assets from the IPA (available now)

| Asset | Files | Status | Used In |
|-------|-------|--------|---------|
| **Color token system** | `cedar-colors.json`, `andy-colors.json`, `opal-colors.json`, `depth-colors.json`, `graphite-colors.json` | ✅ Ready, plain JSON | Theme engine |
| **Theme metadata** | `cedar-theme.json`, `karat-theme.json`, `opal-theme.json`, `presstube-theme.json` | ✅ Ready | Theme switcher |
| **Day/night animation params** | `cedar-animation.json`, `chroma-animation.json` | ✅ Ready | SceneKit transition |
| **Lottie title animation** | `cloudburst-title.json` | ✅ Ready (Lottie v5.7.4) | Page A splash |
| **Particle textures** | `base1.scnassets/precip-particle-{16,32,64,128}.heic` | ⚠️ Need HEIC→PNG | Rain/snow particles |
| **Karat material textures** | `karat.scnassets/gold-dim.heic`, `terrazzo-mask.heic` | ⚠️ Need HEIC→PNG | 3D model material |
| **KTX digit textures** | `presstube.scnassets/*.ktx` (32 files) | ⚠️ Need KTX→PNG | Presstube theme numbers |
| **Sound effects** | 14 × `.caf` files | ⚠️ Need CAF→M4A/MP3 | UI feedback audio |
| **3D scene files** | `*/Models.scn`, `*/Main.scn`, `*/Particles.scn`, `base1.scnassets/Animation-*.scn` | ⚠️ Need macOS export | SceneKit scene |

### 1.2 Assets We Build from Scratch

| Asset | Reason |
|-------|--------|
| Xcode project + bundle structure | New project |
| App icon | Original is copyrighted |
| Fonts | `FoundersGrotesk` / `NeumaticGothic` are commercial → replace |
| All Swift source code | Logic, views, models |
| SF Symbols icon set for weather conditions | Free, built into iOS |
| Mock weather data | No API |
| Detail page card layout | Not visible in IPA |

---

## 2. Division of Work

### 🙋 Tasks That Require YOU (macOS + Xcode)

These cannot be done in code — they require macOS tools or Xcode signing.

#### Step U-1 · Export `.scn` files → `.dae` (one-time, macOS)

Create this Swift command-line script on a Mac and run it:

```swift
// export_scenes.swift — run with: swift export_scenes.swift
import SceneKit
import Foundation

let appPath = "/path/to/simple-weather.app"
let outputDir = "/path/to/output"

let scnFiles: [(String, String)] = [
    ("normal.scnassets/Models.scn",    "normal_models"),
    ("normal.scnassets/Main.scn",      "normal_main"),
    ("normal.scnassets/Particles.scn", "normal_particles"),
    ("andy.scnassets/Models.scn",      "andy_models"),
    ("andy.scnassets/Main.scn",        "andy_main"),
    ("karat.scnassets/Models.scn",     "karat_models"),
    ("karat.scnassets/Main.scn",       "karat_main"),
    ("wireframe.scnassets/Models.scn", "wireframe_models"),
    ("base1.scnassets/Particles.scn",  "base1_particles"),
    // Animation scenes from base1
    ("base1.scnassets/Animation-cloud-in.scn",  "anim_cloud_in"),
    ("base1.scnassets/Animation-cloud-out.scn", "anim_cloud_out"),
    ("base1.scnassets/Animation-cloud.scn",     "anim_cloud"),
    ("base1.scnassets/Animation-sun-in.scn",    "anim_sun_in"),
    ("base1.scnassets/Animation-sun-out.scn",   "anim_sun_out"),
    ("base1.scnassets/Animation-bolt.scn",      "anim_bolt"),
    ("base1.scnassets/Animation-fog.scn",       "anim_fog"),
    ("base1.scnassets/Animation-pop.scn",       "anim_pop"),
]

for (rel, name) in scnFiles {
    let url = URL(fileURLWithPath: "\(appPath)/\(rel)")
    guard let scene = try? SCNScene(url: url, options: nil) else {
        print("❌ Failed: \(rel)"); continue
    }
    let out = URL(fileURLWithPath: "\(outputDir)/\(name).dae")
    scene.write(to: out, options: nil, delegate: nil, progressHandler: nil)
    print("✅ \(name).dae")
}
```

**Deliverable**: A folder of `.dae` files to add to the Xcode project.

---

#### Step U-2 · Convert HEIC textures → PNG (macOS, one command)

```bash
# In Terminal on macOS:
cd /path/to/simple-weather.app

# Particle textures
sips -s format png base1.scnassets/precip-particle-128.heic --out ~/Desktop/textures/precip-128.png
sips -s format png base1.scnassets/precip-particle-64.heic  --out ~/Desktop/textures/precip-64.png
sips -s format png base1.scnassets/precip-particle-32.heic  --out ~/Desktop/textures/precip-32.png

# Karat material textures
sips -s format png karat.scnassets/gold-dim.heic     --out ~/Desktop/textures/gold-dim.png
sips -s format png karat.scnassets/terrazzo-mask.heic --out ~/Desktop/textures/terrazzo-mask.png

# Shirt model texture
sips -s format png shirt003-texture-1024.heic --out ~/Desktop/textures/shirt-texture.png
```

**Deliverable**: 6 PNG files → add to `Assets.xcassets` in Xcode.

---

#### Step U-3 · Convert audio CAF → M4A (macOS, one command)

```bash
# Convert all .caf to .m4a for AVFoundation compatibility
for f in *.caf; do
  afconvert -f m4af -d aac "$f" "${f%.caf}.m4a"
done
```

**Deliverable**: 14 `.m4a` files → add to Xcode project bundle.

---

#### Step U-4 · Create Xcode Project

1. Xcode → New Project → **iOS App**
2. Product Name: `WeatherDemo`
3. Interface: **SwiftUI**
4. Language: **Swift**
5. Minimum Deployment: **iOS 16.0**
6. Bundle Identifier: your choice (e.g. `com.yourname.weatherdemo`)
7. Remove `ContentView.swift` — we'll replace the entire source tree

**Deliverable**: Empty Xcode project folder.

---

#### Step U-5 · Add Assets to Xcode Project

After I deliver the code:

1. Drag all exported `.dae` files → new group `Assets/Scenes/` in Xcode (check "Copy items if needed")
2. Add PNG textures → `Assets.xcassets`
3. Add `.m4a` audio files → new group `Assets/Audio/`
4. Copy all 5 `*-colors.json` files → new group `Assets/Themes/`
5. Copy `cedar-animation.json` → same group
6. Copy `cloudburst-title.json` → bundle root (for Lottie)
7. Install **Lottie** via Swift Package Manager:
   - URL: `https://github.com/airbnb/lottie-ios`
   - Version: `≥ 4.4.0`

---

#### Step U-6 · Choose Starting Theme

Pick one color theme to start with (I'll implement all, you pick the default):

| Theme | Palette | Mood |
|-------|---------|------|
| `cedar` | Teal + Warm Yellow | Nature / Forest |
| `andy` | Amber + Deep Brown | Warm Gold |
| `opal` | Deep Purple + White | Gem / Night |
| `depth` | Pure Black & White | Minimal |
| `graphite` | Dark Gray + Color accents | High Contrast |

---

### 👨‍💻 Tasks I Will Code (Complete Swift Source)

All files listed below are delivered as complete, ready-to-paste Swift source.

---

## 3. Project Structure (What I'll Deliver)

```
WeatherDemo/
├── App/
│   ├── WeatherDemoApp.swift          # App entry point
│   └── AppEnvironment.swift          # Global state (theme, colorScheme, mockData)
│
├── Model/
│   ├── MockWeatherData.swift         # All hardcoded weather data
│   ├── WeatherCondition.swift        # Enum: clear/cloudy/rain/snow/thunderstorm/fog
│   ├── DayForecast.swift             # Struct: date, high, low, condition, weekday
│   └── DetailMetric.swift            # Struct: label, value, unit, icon (SF Symbol)
│
├── Theme/
│   ├── ThemeLoader.swift             # Parses *-colors.json into ThemeColors
│   ├── ThemeColors.swift             # Typed struct for palette + elements
│   ├── AnimationConfig.swift         # Parses cedar-animation.json → typed actions
│   └── ThemeEnvironmentKey.swift     # SwiftUI EnvironmentKey for current theme
│
├── SceneKit/
│   ├── WeatherSceneView.swift        # UIViewRepresentable wrapping SCNView
│   ├── WeatherSceneManager.swift     # Loads .scn, manages nodes, triggers animations
│   ├── WeatherAnimator.swift         # Applies animation.json actions: planeColor, fog, crossFade
│   ├── ParticleController.swift      # Controls rain/snow SCNParticleSystem
│   └── SceneConstants.swift          # Node name constants matching exported .scn
│
├── Views/
│   ├── PageA/
│   │   ├── MainWeatherView.swift     # Root view for Page A
│   │   ├── CurrentConditionOverlay.swift  # City, temp, condition text overlay
│   │   ├── WeeklyForecastStrip.swift # Bottom horizontal 7-day strip
│   │   └── ForecastDayCell.swift     # Single day cell: weekday, icon, H/L
│   │
│   └── PageB/
│       ├── DetailWeatherView.swift   # Root view for Page B (sheet or full screen)
│       ├── DetailHeaderView.swift    # Temp + condition summary at top
│       ├── MetricCardGrid.swift      # 2-column grid of metric cards
│       └── MetricCard.swift          # Single card: icon, label, value, mini-chart
│
├── Components/
│   ├── LottieView.swift              # UIViewRepresentable for Lottie animation
│   ├── DayNightToggle.swift          # Dev toggle to switch day/night for testing
│   └── ThemeSwitcher.swift           # Dev overlay to cycle through themes
│
└── Assets/
    ├── Themes/                       # JSON files (cedar-colors.json etc.)
    ├── Scenes/                       # Exported .dae files (you add these)
    └── Audio/                        # Converted .m4a files (you add these)
```

---

## 4. Page A — Main Weather View (Detailed Spec)

```
┌──────────────────────────────────┐
│  ← STATUS BAR (dynamic color)   │
│                                  │
│  [FULL SCREEN SCNView]           │
│   3D weather model centered      │
│   (cloud / sun / rain scene)     │
│   fog + particle overlay         │
│   background plane (day/night)   │
│                                  │
│  ┌────────────────────────────┐  │
│  │  San Francisco        🌙   │  │ ← city + day/night toggle (dev)
│  │  72°          Partly Cloudy│  │ ← big temp, condition
│  │  H:79°  L:61°              │  │ ← high/low
│  └────────────────────────────┘  │
│                                  │
│  ╔══════════════════════════════╗ │
│  ║ 7-DAY FORECAST STRIP (SwipeX)║ │
│  ║ Mon  Tue  Wed  Thu  Fri ...  ║ │
│  ║ ☁️   ☀️   🌧   ❄️   ☀️       ║ │
│  ║ 79/61 82/63 70/58 65/52...  ║ │
│  ╚══════════════════════════════╝ │
└──────────────────────────────────┘
         tap scene → Page B
```

### SceneKit Scene Composition (Page A)

| Node | Source | Notes |
|------|--------|-------|
| `plane-day` / `plane-night` | `normal.scnassets/Main.scn` | Background plane, crossFade on day/night switch |
| Weather 3D model | `normal.scnassets/Models.scn` | Cloud / sun / rain model, swapped per condition |
| Fog node | SceneKit `SCNFog` on `SCNScene` | Color driven by `animation.json → fogColor` |
| Rain particles | `base1.scnassets/Particles.scn` + `precip-particle-64.png` | Shown when condition = rain/snow |
| Animation triggers | `base1.scnassets/Animation-cloud-in.scn` etc. | Played on condition change |

### Mock Data for Page A

```swift
// MockWeatherData.swift (I'll write this)
let currentWeather = CurrentWeather(
    city: "San Francisco",
    temperature: 72,
    condition: .partlyCloudy,
    high: 79, low: 61,
    isNight: false
)

let weeklyForecast: [DayForecast] = [
    DayForecast(weekday: "Today", condition: .partlyCloudy, high: 79, low: 61),
    DayForecast(weekday: "Tue",   condition: .clear,        high: 82, low: 63),
    DayForecast(weekday: "Wed",   condition: .rain,         high: 70, low: 58),
    DayForecast(weekday: "Thu",   condition: .snow,         high: 65, low: 52),
    DayForecast(weekday: "Fri",   condition: .thunderstorm, high: 68, low: 55),
    DayForecast(weekday: "Sat",   condition: .fog,          high: 66, low: 57),
    DayForecast(weekday: "Sun",   condition: .clear,        high: 75, low: 60),
]
```

---

## 5. Page B — Detail Weather View (Detailed Spec)

```
┌──────────────────────────────────┐
│  ╔════════════ HEADER ═════════╗  │
│  ║  Partly Cloudy              ║  │
│  ║  72°  ·  San Francisco      ║  │
│  ║  [mini 3D scene or icon]    ║  │
│  ╚═════════════════════════════╝  │
│                                  │
│  ┌───────────┐  ┌───────────┐   │
│  │ 🌡 TEMP   │  │ 💧 FEELS  │   │
│  │   72°F    │  │   68°F    │   │  ← card row 1
│  │ H:79 L:61 │  │  Humidity │   │
│  └───────────┘  └───────────┘   │
│  ┌───────────┐  ┌───────────┐   │
│  │ 💨 WIND   │  │ 🌧 PRECIP │   │
│  │  12 mph   │  │   20%     │   │  ← card row 2
│  │  WSW      │  │  0.0 in   │   │
│  └───────────┘  └───────────┘   │
│  ┌───────────┐  ┌───────────┐   │
│  │ ☀️ UV     │  │ 👁 VISIB  │   │
│  │  Index 4  │  │  10 mi    │   │  ← card row 3
│  │  Moderate │  │  Clear    │   │
│  └───────────┘  └───────────┘   │
│  ┌──────────────────────────┐   │
│  │ 🌅 SUNRISE     6:42 AM   │   │  ← wide card
│  │ 🌇 SUNSET      7:18 PM   │   │
│  └──────────────────────────┘   │
│                                  │
│  ▼ swipe down to dismiss         │
└──────────────────────────────────┘
```

### 8 Metric Cards (Mock Values)

| # | Card | Value | Unit | SF Symbol |
|---|------|-------|------|-----------|
| 1 | Temperature | 72 / H:79 / L:61 | °F | `thermometer.medium` |
| 2 | Feels Like | 68 | °F | `thermometer.low` |
| 3 | Wind | 12 mph · WSW | — | `wind` |
| 4 | Precipitation | 20% · 0.0 in | — | `drop.fill` |
| 5 | Humidity | 74% | — | `humidity.fill` |
| 6 | UV Index | 4 · Moderate | — | `sun.max.fill` |
| 7 | Visibility | 10 mi | — | `eye.fill` |
| 8 | Sunrise / Sunset | 6:42 AM / 7:18 PM | — | `sunrise.fill` |

### Page B SceneKit

- Reuse the same `WeatherSceneView` component but scaled down (`0.6×`) or replaced with a static `SCNView` snapshot for the header
- Alternatively: a blurred/frosted glass `UIBlurEffect` background using the same color from the active theme

---

## 6. Theme System Architecture

### 6.1 How the JSON maps to Swift

```
cedar-colors.json
├── colors.palette          →  ThemeColors.palette: [String: Color]
├── colors.elements         →  ThemeColors.elements: [String: ElementColor]
│   ├── genericText         →     .genericText(light:, dark:)
│   ├── weeklyDay           →     .weeklyDay(light:, dark:)
│   └── ...23 elements      →     ...
├── codes                   →  ThemeColors.conditionColorMap: [WeatherCondition: String]
└── icons                   →  ThemeColors.conditionLayers: [WeatherCondition: [IconLayer]]
```

### 6.2 Color Reference Resolution

Many color values in the JSON are **aliases** (e.g. `"dark"`, `"light, a:0.15"`, `"white"`). The `ThemeLoader` will resolve them in two passes:

```
Pass 1: Build palette dict → { "light": Color(r,g,b), "dark": Color(...), ... }
Pass 2: Resolve element strings:
  "dark"         → palette["dark"]
  "dark, a:0.4"  → palette["dark"].opacity(0.4)
  "highlight"    → palette["highlight"]
  "white"        → Color.white
  "black"        → Color.black
  "R:124,G:176,B:172,A:255"  → Color(r:124/255, g:176/255, b:172/255)
```

### 6.3 Day/Night Color Selection

All UI text and icon colors switch between `.light` and `.dark` variants based on the current `isNight: Bool` state. This is passed through SwiftUI environment:

```swift
@Environment(\.colorScheme) var colorScheme
// or our own:
@EnvironmentObject var appState: AppEnvironment  // appState.isNight
```

---

## 7. SceneKit Animation System

### 7.1 Animation Triggers (from `cedar-animation.json`)

| Trigger Event | Actions Performed |
|---------------|-------------------|
| `sunIn` (day) | planeColor → `161,157,104` · fog → `99,125,81 α:0.5` · crossFade `plane-night → plane-day` · statusBar dark |
| `moonIn` (night) | planeColor → `49,45,49` · fog → `49,45,49 α:0.75` · crossFade `plane-day → plane-night` · statusBar light |

### 7.2 Weather Condition → Scene Swap

| Condition | 3D Model Node | Animation Played | Particles |
|-----------|--------------|-----------------|-----------|
| `clear` | `sun` node | `Animation-sun-in.scn` | none |
| `partlyCloudy` / `cloudy` | `cloud` node | `Animation-cloud-in.scn` | none |
| `rain` / `drizzle` | `cloud` + `rain` | `Animation-cloud-in.scn` | ✅ rain particles |
| `snow` | `cloud` + `snow` | `Animation-cloud-in.scn` | ✅ snow particles |
| `thunderstorm` | `cloud` + `bolt` | `Animation-bolt.scn` | ✅ rain particles |
| `fog` | fog node | `Animation-fog.scn` | none |

### 7.3 `WeatherSceneManager` API (what I'll implement)

```swift
class WeatherSceneManager {
    func loadScene(theme: String)
    func setCondition(_ condition: WeatherCondition, animated: Bool)
    func setNightMode(_ isNight: Bool, animated: Bool)
    func playEntranceAnimation()
    func pauseAnimations()
    func resumeAnimations()
}
```

---

## 8. Audio Integration

Sound effects triggered from SwiftUI interaction events:

| Event | Sound File |
|-------|-----------|
| App launch / scene appear | `detailed-enter-1.m4a` |
| Tap 3D model | `shape-tap-1.m4a` or `shape-tap-7.m4a` |
| Swipe to change day | `ui-day-select-1.m4a` |
| Open detail (Page B) | `menu-open-1.m4a` |
| Dismiss detail | `spin-slow-4.m4a` |
| Ambient background (cloudy) | `weather-ambience-cloudy.m4a` (loop, low volume) |

All audio via `AVAudioPlayer`, managed by a lightweight `AudioManager` singleton.

---

## 9. Delivery Order (Phases)

### Phase 1 · Foundation (I deliver, you set up Xcode)
- [ ] `MockWeatherData.swift` — all hardcoded data
- [ ] `WeatherCondition.swift` — condition enum + SF Symbol mapping
- [ ] `ThemeLoader.swift` + `ThemeColors.swift` — JSON parsing
- [ ] `AppEnvironment.swift` — global state
- [ ] `WeatherDemoApp.swift` — entry point

### Phase 2 · SceneKit Core (after you export `.scn` files)
- [ ] `WeatherSceneView.swift` — SCNView wrapper
- [ ] `WeatherSceneManager.swift` — scene loading + node management
- [ ] `WeatherAnimator.swift` — animation.json actions
- [ ] `ParticleController.swift` — rain/snow particles
- [ ] `SceneConstants.swift`

### Phase 3 · Page A UI
- [ ] `MainWeatherView.swift`
- [ ] `CurrentConditionOverlay.swift`
- [ ] `WeeklyForecastStrip.swift`
- [ ] `ForecastDayCell.swift`

### Phase 4 · Page B UI
- [ ] `DetailWeatherView.swift`
- [ ] `DetailHeaderView.swift`
- [ ] `MetricCardGrid.swift`
- [ ] `MetricCard.swift`

### Phase 5 · Polish
- [ ] `LottieView.swift` — Lottie wrapper
- [ ] `DayNightToggle.swift` — dev toggle
- [ ] `ThemeSwitcher.swift` — cycle themes overlay
- [ ] `AudioManager.swift` — sound effects
- [ ] Navigation transitions (custom push/sheet animation)

---

## 10. Dependencies (Swift Package Manager)

Add these in Xcode → File → Add Package Dependencies:

| Package | URL | Purpose |
|---------|-----|---------|
| **Lottie** | `https://github.com/airbnb/lottie-ios` | `cloudburst-title.json` animation |

No other external dependencies — everything else uses native iOS frameworks:
`SwiftUI`, `SceneKit`, `AVFoundation`, `Combine`, `Foundation`

---

## 11. Fallback Plan (if .scn export fails)

If the `.scn` binary export on macOS fails for any scene file, we have these fallbacks:

| Fallback | Approach |
|----------|---------|
| **Pure SwiftUI 3D illusion** | Use layered `ZStack` with shadows, blur, scale transforms to fake 3D depth — no SceneKit required |
| **RealityKit primitives** | Replace SCNScene with simple `ModelEntity` spheres/boxes + materials; the JSON colors still apply |
| **Lottie-only animation** | Use JSON-driven Lottie animations for weather icons instead of 3D SceneKit — fully cross-platform |

---

## 12. Quick-Start Checklist

```
YOU (macOS tasks):                          ME (code):
─────────────────────────────────────────  ──────────────────────────────────────
□ Run export_scenes.swift on Mac           □ Phase 1: Foundation Swift files
□ Convert HEIC → PNG (sips commands)       □ Phase 2: SceneKit layer
□ Convert CAF → M4A (afconvert commands)   □ Phase 3: Page A views
□ Create Xcode project (Step U-4)          □ Phase 4: Page B views
□ Add all assets to Xcode (Step U-5)       □ Phase 5: Audio + polish
□ Install Lottie via SPM (Step U-5)        □ README with wiring instructions
□ Choose default theme (Step U-6)
□ Run on iPhone simulator
```

---

*Plan version 1.0 · April 2026*  
*App reference: Not Boring Weather by Not Boring Software — for study purposes only*
