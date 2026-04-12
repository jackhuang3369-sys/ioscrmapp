# Weather Spin Interaction Blueprint

## Objective

Refactor the current weather spin logic into tunable, testable layers without changing the SceneKit rendering stack.

## Proposed units

### WeatherSpinTuning
- Owns thresholds, turn caps, durations, and debug flags.
- Lives near the weather SceneKit interaction code.

### WeatherSpinGestureSample
- Captures one drag release sample.
- Stores translation, predicted translation, velocity, duration, and classification.

### WeatherSpinSettleDecision
- Represents the resolved release outcome.
- Stores settle mode, direction, target turns, target yaw, duration, and curve profile.

### WeatherSpinController
- Converts live gesture values into drag state and release decisions.
- Contains no SceneKit node ownership.

### WeatherSpinAnimator
- Applies a `WeatherSpinSettleDecision` to the shared rotating group.
- Handles final-turn slowdown and front-facing snap.

### WeatherSceneManager
- Remains responsible for scene graph, node references, and sun-detail alignment.

## Suggested file direction

- Keep scene graph ownership in `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneManager.swift`
- Keep the SceneKit bridge in `ioscrmapp/Modules/Weather/SceneKit/WeatherSceneView.swift`
- Extract tuning and settle logic into focused helper files under `ioscrmapp/Modules/Weather/SceneKit/`

## Data flow

`UIPanGestureRecognizer` input
-> live drag mapping
-> `WeatherSpinGestureSample`
-> `WeatherSpinController` classification
-> `WeatherSpinSettleDecision`
-> `WeatherSpinAnimator`
-> rotating group yaw update

## Debug surface

Expose optional metrics for:
- drag distance ratio
- velocity
- duration
- slow or fast classification
- target turn count
- settle mode
- current and target yaw

## Integration notes

- Keep bird local animation enabled at all times.
- Treat front-facing as the visible stop state even if cumulative turn count is preserved internally.
- Align to front-facing before entering sun detail to avoid transition jumps.