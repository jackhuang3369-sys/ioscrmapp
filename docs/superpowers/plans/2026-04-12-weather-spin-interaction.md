# Weather Spin Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Weather main-scene spin interaction so it uses deterministic drag-and-settle rules, preserves the front-facing rest pose, and keeps every non-requested animation object unchanged.

**Architecture:** Extract all gesture classification and settle math into a pure Swift spin core so it can be smoke-tested without SceneKit. Keep SceneKit as the renderer, wire the pure spin core into `WeatherSceneView.Coordinator`, and gate sun-detail entry until the scene is front-facing. Do not modify existing sun pulse, bird local animation, sun burst, float animation, audio, or detail-scene auto-spin behavior unless a step below explicitly says so.

**Tech Stack:** Swift, SwiftUI, SceneKit, UIKit gesture recognizers, standalone Swift smoke tests via `swiftc`

---

## File Map

- Create: `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift`
  Purpose: Pure interaction logic for tuning, gesture classification, live drag mapping, settle decisions, and front-facing helpers.

- Create: `SmokeTests/WeatherSpinInteractionSmokeTests.swift`
  Purpose: Standalone smoke tests for the pure spin core. These tests must compile together with `WeatherSpinCore.swift` and run without the app target.

- Modify: `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`
  Purpose: Replace the current coarse momentum path with the pure spin core while preserving current tap handling, scale feedback, and all non-target animation systems.

- Modify: `ioscrmapp/Modules/Weather/Views/WeatherMainView.swift`
  Purpose: Gate sun-detail entry until the shared rotating group has aligned to front-facing.

- Modify only if required: `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift`
  Purpose: Add tiny helper APIs for front-facing checks or alignment callbacks. Do not change asset loading, bird animation setup, sun pulse, float animation, sun burst, or detail transition visuals.

### Animation Freeze Boundary

The following existing behaviors are out of scope and MUST remain unchanged unless an implementation step below explicitly touches them:

- Bird local flap animation from the USDZ asset
- Sun pulse behavior
- Scene float animation
- Sun burst animation
- Detail scene automatic spin
- Audio triggers
- Asset loading, material setup, and lighting

### Task 1: Build the Pure Spin Core

**Files:**
- Create: `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift`
- Create: `SmokeTests/WeatherSpinInteractionSmokeTests.swift`

- [ ] **Step 1: Write the failing smoke test file**

```swift
import Foundation
import CoreGraphics

@main
struct WeatherSpinInteractionSmokeTests {
    static func main() throws {
        try testSlowDragUnderHalfReturnsBackward()
        try testSlowDragOverHalfCommitsForward()
        try testSlowDragOverOneScreenUsesCompletedTurns()
        try testFastDragUnderQuarterReturnsBackward()
        try testFastDragHalfToFullCommitsOneTurn()
        try testFastDragOverHalfCapsAtThreeTurns()
        print("Weather spin smoke tests passed")
    }

    private static let tuning = WeatherSpinTuning.default

    private static func testSlowDragUnderHalfReturnsBackward() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.24,
            predictedTranslationRatio: 0.26,
            velocityPointsPerSecond: 180,
            duration: 0.44
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 86,
            sample: sample
        )
        try require(decision.mode == .reverseReturnToFront, "slow drag under half should return backward")
    }

    private static func testSlowDragOverHalfCommitsForward() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.72,
            predictedTranslationRatio: 0.76,
            velocityPointsPerSecond: 220,
            duration: 0.47
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 242,
            sample: sample
        )
        try require(decision.mode == .forwardCompleteToFront, "slow drag over half should complete forward")
    }

    private static func testSlowDragOverOneScreenUsesCompletedTurns() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 1.36,
            predictedTranslationRatio: 1.38,
            velocityPointsPerSecond: 260,
            duration: 0.52
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 492,
            sample: sample
        )
        try require(decision.targetTurnCount == 2, "slow drag over one screen should keep completed forward turn progress")
    }

    private static func testFastDragUnderQuarterReturnsBackward() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.18,
            predictedTranslationRatio: 0.22,
            velocityPointsPerSecond: 1240,
            duration: 0.12
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 70,
            sample: sample
        )
        try require(decision.mode == .reverseReturnToFront, "fast short drag should return backward")
    }

    private static func testFastDragHalfToFullCommitsOneTurn() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.38,
            predictedTranslationRatio: 0.46,
            velocityPointsPerSecond: 1180,
            duration: 0.14
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 128,
            sample: sample
        )
        try require(decision.mode == .forwardSingleTurn, "fast drag between quarter and half should commit one turn")
    }

    private static func testFastDragOverHalfCapsAtThreeTurns() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.84,
            predictedTranslationRatio: 2.40,
            velocityPointsPerSecond: 1680,
            duration: 0.16
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 210,
            sample: sample
        )
        try require(decision.mode == .forwardMomentumTurns, "fast long drag should use momentum turns")
        try require(decision.targetTurnCount == 3, "fast long drag should cap total turns at three")
        try require(decision.usesFinalTurnSlowdown, "momentum settle should slow the final turn")
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(domain: "WeatherSpinSmokeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
```

- [ ] **Step 2: Run smoke tests to verify they fail**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift -o /tmp/weather-spin-smoke
```

Expected: FAIL with errors such as `cannot find 'WeatherSpinTuning' in scope`.

- [ ] **Step 3: Write the minimal pure spin core**

Create `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift` with this initial implementation:

```swift
import CoreGraphics
import Foundation

enum WeatherSpinSettleMode: Equatable {
    case reverseReturnToFront
    case forwardCompleteToFront
    case forwardSingleTurn
    case forwardMomentumTurns
}

struct WeatherSpinTuning {
    let fullScreenTurnDegrees: CGFloat
    let slowSwipeMaxDuration: TimeInterval
    let fastSwipeMinVelocity: CGFloat
    let fastSwipeMinDistanceRatio: CGFloat
    let quarterScreenFlickThreshold: CGFloat
    let halfScreenCommitThreshold: CGFloat
    let projectedDistanceMultiplier: CGFloat
    let maxMomentumTurns: Int
    let finalTurnSlowdownStartRatio: CGFloat

    static let `default` = WeatherSpinTuning(
        fullScreenTurnDegrees: 360,
        slowSwipeMaxDuration: 0.48,
        fastSwipeMinVelocity: 1050,
        fastSwipeMinDistanceRatio: 0.08,
        quarterScreenFlickThreshold: 0.25,
        halfScreenCommitThreshold: 0.5,
        projectedDistanceMultiplier: 1.22,
        maxMomentumTurns: 3,
        finalTurnSlowdownStartRatio: 0.75
    )
}

struct WeatherSpinGestureSample {
    let translationRatio: CGFloat
    let predictedTranslationRatio: CGFloat
    let velocityPointsPerSecond: CGFloat
    let duration: TimeInterval

    var isFast: Bool {
        duration <= WeatherSpinTuning.default.slowSwipeMaxDuration
            && abs(velocityPointsPerSecond) >= WeatherSpinTuning.default.fastSwipeMinVelocity
            && abs(translationRatio) >= WeatherSpinTuning.default.fastSwipeMinDistanceRatio
    }
}

struct WeatherSpinSettleDecision: Equatable {
    let mode: WeatherSpinSettleMode
    let targetTurnCount: Int
    let targetYawDegrees: CGFloat
    let usesFinalTurnSlowdown: Bool
}

struct WeatherSpinController {
    let tuning: WeatherSpinTuning

    func liveYawDegrees(for translationRatio: CGFloat) -> CGFloat {
        translationRatio * tuning.fullScreenTurnDegrees
    }

    func settleDecision(currentYawDegrees: CGFloat, sample: WeatherSpinGestureSample) -> WeatherSpinSettleDecision {
        let absoluteTranslation = abs(sample.translationRatio)
        let absolutePredicted = abs(sample.predictedTranslationRatio) * tuning.projectedDistanceMultiplier
        let completedTurns = max(Int(floor(abs(currentYawDegrees) / tuning.fullScreenTurnDegrees)), 0)

        if sample.isFast {
            if absoluteTranslation < tuning.quarterScreenFlickThreshold {
                return WeatherSpinSettleDecision(mode: .reverseReturnToFront, targetTurnCount: 0, targetYawDegrees: 0, usesFinalTurnSlowdown: false)
            }
            if absoluteTranslation < tuning.halfScreenCommitThreshold {
                return WeatherSpinSettleDecision(mode: .forwardSingleTurn, targetTurnCount: 1, targetYawDegrees: tuning.fullScreenTurnDegrees, usesFinalTurnSlowdown: true)
            }

            let projectedTurns = max(Int(ceil(absolutePredicted)), 1)
            let cappedTurns = min(projectedTurns, tuning.maxMomentumTurns)
            return WeatherSpinSettleDecision(mode: .forwardMomentumTurns, targetTurnCount: cappedTurns, targetYawDegrees: CGFloat(cappedTurns) * tuning.fullScreenTurnDegrees, usesFinalTurnSlowdown: true)
        }

        if absoluteTranslation < tuning.halfScreenCommitThreshold {
            return WeatherSpinSettleDecision(mode: .reverseReturnToFront, targetTurnCount: 0, targetYawDegrees: 0, usesFinalTurnSlowdown: false)
        }

        if absoluteTranslation < 1 {
            return WeatherSpinSettleDecision(mode: .forwardCompleteToFront, targetTurnCount: 1, targetYawDegrees: tuning.fullScreenTurnDegrees, usesFinalTurnSlowdown: true)
        }

        let forwardTurns = max(completedTurns, 1)
        return WeatherSpinSettleDecision(mode: .forwardCompleteToFront, targetTurnCount: forwardTurns, targetYawDegrees: CGFloat(forwardTurns) * tuning.fullScreenTurnDegrees, usesFinalTurnSlowdown: true)
    }

    func isFrontFacing(yawDegrees: CGFloat, toleranceDegrees: CGFloat) -> Bool {
        let normalized = abs(yawDegrees.truncatingRemainder(dividingBy: tuning.fullScreenTurnDegrees))
        return normalized <= toleranceDegrees || abs(normalized - tuning.fullScreenTurnDegrees) <= toleranceDegrees
    }
}
```

- [ ] **Step 4: Run smoke tests to verify they pass**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke
/tmp/weather-spin-smoke
```

Expected: Prints `Weather spin smoke tests passed`.

- [ ] **Step 5: Commit**

```bash
cd /Users/ray/Documents/Code/ioscrmapp
git add SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift
git commit -m "feat: add weather spin core"
```

### Task 2: Wire the Spin Core into WeatherSceneView

**Files:**
- Modify: `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`
- Modify: `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift`
- Test: `SmokeTests/WeatherSpinInteractionSmokeTests.swift`

- [ ] **Step 1: Extend the smoke tests with adapter expectations**

Append these tests to `SmokeTests/WeatherSpinInteractionSmokeTests.swift`:

```swift
private static func testLiveYawUsesOneScreenOneTurnMapping() throws {
    let controller = WeatherSpinController(tuning: tuning)
    try require(controller.liveYawDegrees(for: 1.0) == 360, "full-screen drag should equal one turn")
    try require(controller.liveYawDegrees(for: 0.5) == 180, "half-screen drag should equal half turn")
}

private static func testFrontFacingHelperTreatsFullTurnsAsFrontFacing() throws {
    let controller = WeatherSpinController(tuning: tuning)
    try require(controller.isFrontFacing(yawDegrees: 0, toleranceDegrees: 8), "0 degrees should be front-facing")
    try require(controller.isFrontFacing(yawDegrees: 360, toleranceDegrees: 8), "360 degrees should be front-facing")
    try require(!controller.isFrontFacing(yawDegrees: 120, toleranceDegrees: 8), "off-axis yaw should not be front-facing")
}
```

- [ ] **Step 2: Run smoke tests to verify the added assertions pass and keep this as a regression baseline**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke
/tmp/weather-spin-smoke
```

Expected: PASS if Task 1 is complete; keep this command as the fast regression check before SceneKit wiring.

- [ ] **Step 3: Replace the coarse momentum constants with a spin-core-backed coordinator state**

Update `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift` so the coordinator owns a `WeatherSpinController`, tracks gesture start time, and keeps all non-target animation systems untouched.

Use this shape for the new coordinator properties:

```swift
private let spinController = WeatherSpinController(tuning: .default)
private let frontFacingToleranceDegrees: CGFloat = 8
private var panStartTime: CFTimeInterval?
private var currentYawDegrees: CGFloat = 0
private var targetYawDegrees: CGFloat = 0
private var pendingDetailEntryRequestVersion: Int = 0
```

Replace the current full-width sensitivity with one-screen-one-turn mapping:

```swift
private func dragRatio(for translationX: CGFloat, view: UIView?) -> CGFloat {
    let width = max(view?.bounds.width ?? 0, 1)
    return translationX / width
}
```

In `handlePan(.changed)`, keep the current scale feedback and tap behavior, but switch yaw updates to:

```swift
let translation = gesture.translation(in: gesture.view)
let ratio = dragRatio(for: translation.x, view: gesture.view)
targetYawDegrees = spinController.liveYawDegrees(for: ratio)
currentYawDegrees += (targetYawDegrees - currentYawDegrees) * 0.34
targetYaw = Float(targetYawDegrees * .pi / 180)
currentYaw = Float(currentYawDegrees * .pi / 180)
```

Do not change these existing systems in this step:
- tap hit testing
- scale feedback on begin or end
- sun pulse
- bird local animation
- scene float
- sun burst
- detail auto-spin

- [ ] **Step 4: Replace horizontal momentum settle with explicit settle decisions**

In `handlePan(.ended/.cancelled)`, replace `startHorizontalYawMomentum` for horizontal drags with a core-driven decision:

```swift
let duration = max((panStartTime.map { CACurrentMediaTime() - $0 } ?? 0.16), 0.01)
let translation = gesture.translation(in: gesture.view)
let predicted = gesture.velocity(in: gesture.view).x * 0.00035 + translation.x
let sample = WeatherSpinGestureSample(
    translationRatio: dragRatio(for: translation.x, view: gesture.view),
    predictedTranslationRatio: dragRatio(for: predicted, view: gesture.view),
    velocityPointsPerSecond: gesture.velocity(in: gesture.view).x,
    duration: duration
)
let decision = spinController.settleDecision(
    currentYawDegrees: currentYawDegrees,
    sample: sample
)
startSettleAnimation(decision: decision, restPitch: restPitch)
```

Create `startSettleAnimation(decision:restPitch:)` to convert target degrees to yaw radians and keep the existing pitch and roll reset behavior. When `decision.usesFinalTurnSlowdown` is `true`, use the longer ease-out profile already used by `OrientationAnimation` and reserve the softer curve for the final segment.

- [ ] **Step 5: Build the app target to verify SceneKit wiring compiles**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/ray/Documents/Code/ioscrmapp
git add ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift SmokeTests/WeatherSpinInteractionSmokeTests.swift
git commit -m "feat: wire weather spin core into scene view"
```

### Task 3: Gate Sun Detail Entry and Keep Other Animations Unchanged

**Files:**
- Modify: `ioscrmapp/Modules/Weather/Views/WeatherMainView.swift`
- Modify: `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`
- Modify only if required: `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift`
- Test: `SmokeTests/WeatherSpinInteractionSmokeTests.swift`

- [ ] **Step 1: Add front-facing gate smoke tests**

Append this test to `SmokeTests/WeatherSpinInteractionSmokeTests.swift`:

```swift
private static func testFrontFacingToleranceBlocksDetailEntryUntilAligned() throws {
    let controller = WeatherSpinController(tuning: tuning)
    try require(!controller.isFrontFacing(yawDegrees: 24, toleranceDegrees: 8), "24 degrees should still block detail entry")
    try require(controller.isFrontFacing(yawDegrees: 4, toleranceDegrees: 8), "small yaw should allow detail entry")
}
```

- [ ] **Step 2: Run smoke tests to verify the front-facing gate assumptions hold**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke
/tmp/weather-spin-smoke
```

Expected: `Weather spin smoke tests passed`

- [ ] **Step 3: Add a front-facing alignment request path from WeatherMainView to WeatherSceneView**

In `ioscrmapp/Modules/Weather/Views/WeatherMainView.swift`, add state for deferred detail entry:

```swift
@State private var detailEntryAlignmentRequestVersion = 0
@State private var isWaitingForFrontFacingEntry = false
```

Pass two new parameters into `WeatherSceneView`:

```swift
WeatherSceneView(
    scene: sceneManager.scene,
    manager: sceneManager,
    onSunTap: enterSunDetail,
    onBackgroundTap: isSunDetailPresented ? exitSunDetail : nil,
    interactionResetVersion: sceneInteractionResetVersion,
    detailEntryAlignmentRequestVersion: detailEntryAlignmentRequestVersion,
    onDetailEntryAlignmentComplete: continueSunDetailEntry
)
```

Split the current `enterSunDetail()` into a gate and a continuation:

```swift
private func enterSunDetail() {
    guard !isSunDetailPresented, !isSunTransitionActive else { return }

    let isFrontFacing = sceneManager.isDisplayGroupFrontFacing(toleranceDegrees: 8)
    if !isFrontFacing {
        isWaitingForFrontFacingEntry = true
        detailEntryAlignmentRequestVersion += 1
        return
    }

    continueSunDetailEntry()
}

private func continueSunDetailEntry() {
    guard !isSunDetailPresented, !isSunTransitionActive else { return }
    isWaitingForFrontFacingEntry = false

    sceneManager.prepareSunDetailTransition(
        temperature: selectedEntry.temperature,
        sourceRotation: sceneManager.displayGroupRotation
    )
    sceneManager.setTemperatureVisibility(isHidden: true, animated: true)
    detailOverlayOpacity = 0
    isSunTransitionActive = true

    withAnimation(.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.10)) {
        isSunDetailPresented = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
        guard isSunDetailPresented else { return }
        withAnimation(.easeOut(duration: 0.34)) {
            detailOverlayOpacity = 1
        }
    }

    sceneManager.startSunDetailTransition {
        guard isSunDetailPresented else { return }
        sceneInteractionResetVersion += 1
        isSunTransitionActive = false
    }
    WeatherAudioPlayer.shared.playDetailedEnter()
}
```

- [ ] **Step 4: Handle the alignment request inside WeatherSceneView without changing unrelated animation systems**

In `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`, add:

```swift
let detailEntryAlignmentRequestVersion: Int
let onDetailEntryAlignmentComplete: (() -> Void)?
```

Inside the coordinator, remember the last handled version and on `updateUIView` start a front-facing settle animation only when a new request arrives. Reuse the same settle animation path as drag release, but force a `.reverseReturnToFront` or shortest front-facing alignment decision.

Use this guard in `updateUIView`:

```swift
context.coordinator.applyDetailEntryAlignmentIfNeeded(
    requestVersion: detailEntryAlignmentRequestVersion,
    onComplete: onDetailEntryAlignmentComplete
)
```

Inside `applyDetailEntryAlignmentIfNeeded`, call the completion only after the front-facing animation finishes.

Do not edit these methods in this step unless the build forces you to:
- `attachSunPulse`
- `attachFloatAnimation`
- bird asset loading and material code
- `runSunBurstAnimation`
- `startSunDetailTransition`
- `startReturnToMainTransition`

- [ ] **Step 5: Add the smallest manager helper only if needed**

If `WeatherMainView` needs a direct query, add this helper to `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift` and leave all animation builders untouched:

```swift
func isDisplayGroupFrontFacing(toleranceDegrees: CGFloat) -> Bool {
    let yawDegrees = CGFloat(displayGroupRotation.y) * 180 / .pi
    return WeatherSpinController(tuning: .default).isFrontFacing(
        yawDegrees: yawDegrees,
        toleranceDegrees: toleranceDegrees
    )
}
```

- [ ] **Step 6: Build the app target and confirm no unrelated animation systems were edited**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp -destination 'generic/platform=iOS Simulator' build
git diff -- ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift ioscrmapp/Modules/Weather/Views/WeatherMainView.swift
```

Expected:
- build output ends with `** BUILD SUCCEEDED **`
- diff shows interaction and detail-entry changes only, not unrelated animation rewrites

- [ ] **Step 7: Commit**

```bash
cd /Users/ray/Documents/Code/ioscrmapp
git add ioscrmapp/Modules/Weather/Views/WeatherMainView.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift SmokeTests/WeatherSpinInteractionSmokeTests.swift
git commit -m "feat: gate weather detail entry on front-facing alignment"
```

### Task 4: Add Debug Telemetry and Final Validation

**Files:**
- Modify: `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift`
- Modify: `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`
- Test: `SmokeTests/WeatherSpinInteractionSmokeTests.swift`

- [ ] **Step 1: Add a debug payload shape in the spin core**

Append this type to `ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift`:

```swift
struct WeatherSpinDebugSnapshot {
    let translationRatio: CGFloat
    let predictedTranslationRatio: CGFloat
    let velocityPointsPerSecond: CGFloat
    let duration: TimeInterval
    let targetTurnCount: Int
    let mode: WeatherSpinSettleMode
}
```

- [ ] **Step 2: Add a smoke test that verifies the three-turn cap remains visible in debug output**

Append this test to `SmokeTests/WeatherSpinInteractionSmokeTests.swift`:

```swift
private static func testDebugSnapshotReflectsTurnCap() throws {
    let sample = WeatherSpinGestureSample(
        translationRatio: 0.92,
        predictedTranslationRatio: 2.8,
        velocityPointsPerSecond: 1800,
        duration: 0.13
    )
    let decision = WeatherSpinController(tuning: tuning).settleDecision(currentYawDegrees: 220, sample: sample)
    let snapshot = WeatherSpinDebugSnapshot(
        translationRatio: sample.translationRatio,
        predictedTranslationRatio: sample.predictedTranslationRatio,
        velocityPointsPerSecond: sample.velocityPointsPerSecond,
        duration: sample.duration,
        targetTurnCount: decision.targetTurnCount,
        mode: decision.mode
    )
    try require(snapshot.targetTurnCount == 3, "debug snapshot should report the capped turn count")
}
```

- [ ] **Step 3: Run smoke tests to verify the debug payload is correct**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke
/tmp/weather-spin-smoke
```

Expected: `Weather spin smoke tests passed`

- [ ] **Step 4: Add opt-in debug logging in WeatherSceneView**

In `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`, add an opt-in debug flag and a single print line after settle decisions:

```swift
private let debugWeatherSpin = false

private func logDecision(sample: WeatherSpinGestureSample, decision: WeatherSpinSettleDecision) {
    guard debugWeatherSpin else { return }
    print(
        "[WeatherSpin] ratio=\(sample.translationRatio) predicted=\(sample.predictedTranslationRatio) velocity=\(sample.velocityPointsPerSecond) duration=\(sample.duration) mode=\(decision.mode) turns=\(decision.targetTurnCount)"
    )
}
```

Call `logDecision(sample:decision:)` immediately before `startSettleAnimation(decision:restPitch:)`.

- [ ] **Step 5: Run smoke tests and app build for final verification**

Run:
```bash
cd /Users/ray/Documents/Code/ioscrmapp
swiftc SmokeTests/WeatherSpinInteractionSmokeTests.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift -o /tmp/weather-spin-smoke
/tmp/weather-spin-smoke
xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp -destination 'generic/platform=iOS Simulator' build
```

Expected:
- smoke test prints `Weather spin smoke tests passed`
- build output ends with `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/ray/Documents/Code/ioscrmapp
git add ioscrmapp/Modules/Weather/SceneKit/WeatherSpinCore.swift ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift SmokeTests/WeatherSpinInteractionSmokeTests.swift
git commit -m "feat: add weather spin debug telemetry"
```

## Self-Review Checklist

- Spec coverage: Task 1 covers tuning, classification, and turn-cap logic. Task 2 covers one-screen-one-turn mapping and release behavior. Task 3 covers front-facing detail entry and the “do not change other animation objects” boundary. Task 4 covers debug output and final validation.
- Placeholder scan: No `TODO`, `TBD`, or unresolved placeholders remain.
- Type consistency: `WeatherSpinTuning`, `WeatherSpinGestureSample`, `WeatherSpinSettleDecision`, and `WeatherSpinController` are used consistently across tasks.