## 1. Unify settle destination policy

- [x] 1.1 Implement a shared normalized-angle helper for release settle destination (0 vs 360 by 180-degree threshold)
- [x] 1.2 Ensure first-screen release path uses the shared destination helper
- [x] 1.3 Ensure second-screen sun release path uses the same destination helper and direction convention

## 2. Unify settle duration and easing model

- [x] 2.1 Introduce shared v1 settle tuning parameters: targetAngularSpeedRadPerSec=4.8, minimumSettleDuration=0.48, maximumSettleDuration=1.45
- [x] 2.2 Replace reverse-only fixed duration logic with shared angular-speed duration formula
- [x] 2.3 Replace second-screen snap-specific duration envelope with the same shared duration formula
- [x] 2.4 Apply the same yaw easing curve (easeOutDecay, k=3.0) to return-to-0 and forward-to-360 settle outcomes

## 3. Preserve existing interaction scope

- [x] 3.1 Keep existing slow/fast gesture classification thresholds unchanged in this change
- [x] 3.2 Keep non-requested weather animation systems unchanged (sun pulse, scene float, burst, assets/light/material)

## 4. Verification

- [x] 4.1 Validate release behavior on first-screen: <180 settles to 0, >=180 settles to 360 in current direction
- [x] 4.2 Validate exact 180-degree boundary on first-screen and second-screen: both MUST settle forward to 360 in current direction
- [x] 4.3 Validate release behavior on second-screen with the same threshold and speed model
- [x] 4.4 Compare perceived speed for tiny-angle and medium-angle releases: return-to-0 and settle-to-360 use the same angular-speed model and no reverse-only fast snap
- [x] 4.5 Run weather-related smoke/build checks and record pass evidence on at least one small and one large device profile before apply
	- Automated evidence (2026-04-16): `swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke && /tmp/weather-spin-smoke` passed.
	- Automated evidence (2026-04-16): `xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop -destination 'platform=iOS Simulator,name=iPhone 17' build` passed with BUILD SUCCEEDED.
	- Automated evidence (2026-04-16): `xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build` passed with BUILD SUCCEEDED.
