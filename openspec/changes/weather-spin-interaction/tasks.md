## 1. Build spin core and smoke tests

- [x] 1.1 Add a pure weather spin core for tuning, gesture samples, settle decisions, and front-facing helpers
- [x] 1.2 Add smoke tests for slow and fast settle branches, one-screen-one-turn mapping, and high-speed multi-turn cap behavior
- [x] 1.3 Keep smoke tests executable outside the app target and use them as the fast regression gate

## 2. Wire spin core into SceneKit interaction

- [x] 2.1 Replace the coarse horizontal momentum path in WeatherSceneView with explicit classification and settle decisions
- [x] 2.2 Map horizontal drag distance so one full screen width equals one full turn
- [x] 2.3 Implement slow-drag settle behavior for under-half, over-half, and over-one-screen release cases
- [x] 2.4 Implement fast-drag settle behavior for under-quarter, quarter-to-half, and projected multi-turn release cases
- [x] 2.5 Cap projected fast settles at a bounded maximum turn count and apply controlled end-phase easing

## 3. Gate detail entry and preserve existing animations

- [x] 3.1 Require front-facing alignment before entering sun detail
- [x] 3.2 Preserve bird local animation while the shared rotating assembly turns
- [x] 3.3 Keep non-requested animation systems unchanged: sun pulse, scene float, sun burst, detail auto-spin, audio, and asset-material-lighting behavior

## 4. Debug telemetry and final verification

- [x] 4.1 Add debug output support for distance, velocity, classification, target turns, and yaw state
- [x] 4.2 Validate slow-drag over-one-screen behavior and fast multi-turn cap behavior against the interaction contract
- [x] 4.3 Validate behavior on at least one small device and one large device and tune thresholds from observed results
	- Automated evidence: `xcodebuild` succeeded for `iPhone 17` (small) and `iPhone 17 Pro Max` (large).
	- Automated evidence (2026-04-13): weather spin smoke tests passed via
	  `swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke && /tmp/weather-spin-smoke`.
	- Automated evidence (2026-04-13): `xcodebuild` revalidated for both `iPhone 17` and `iPhone 17 Pro Max` with `BUILD SUCCEEDED`.
	- Manual validation (2026-04-13, user-confirmed): small + large device swipe-release interaction passed with tuned short-distance high-speed behavior; no blocker remains for this change.