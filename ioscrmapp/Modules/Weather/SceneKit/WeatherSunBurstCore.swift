import Foundation

enum WeatherSunBurstCore {
    static let rayCount = 20

    static let minRayLength: Float = 2.0
    static let maxRayLength: Float = 6.5
    static let minOutwardDistance: Float = 0.5
    static let maxOutwardDistance: Float = 1.2

    static let minJitter: Float = 0.95
    static let maxJitter: Float = 1.05
    static let sunRadius: Float = 2.44
    static let burstZOffset: Float = -1.22  // -sunRadius * 0.5，将爆发中心置于太阳球体后方

    static let springMainDuration: TimeInterval = 0.46
    static let springBounceDuration: TimeInterval = 0.10
    static let springTotalDuration: TimeInterval = springMainDuration + springBounceDuration
    static let springOvershootY: Float = -0.22
    static let springTargetY: Float = -0.04
    static let springOvershootScale: Float = 0.82
    static let springTargetScale: Float = 0.84

    static let layerDelayStep: TimeInterval = 0.015

    static func lerp(_ start: Float, _ end: Float, _ progress: Float) -> Float {
        start + (end - start) * progress
    }

    static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    static func depthProgress(forZ z: Float) -> Float {
        clamped01((z + 1) / 2)
    }

    static func colorWhite(forZ z: Float) -> Float {
        lerp(0.85, 0.02, depthProgress(forZ: z))
    }

    static func materialAlpha(forZ z: Float) -> Float {
        lerp(0.28, 0.92, depthProgress(forZ: z))
    }

    static func thickness(forZ z: Float) -> Float {
        lerp(0.038, 0.056, depthProgress(forZ: z))
    }

    static func outwardDistance(forLength length: Float) -> Float {
        let normalized = clamped01((length - minRayLength) / (maxRayLength - minRayLength))
        return lerp(minOutwardDistance, maxOutwardDistance, normalized)
    }

    static func delayOffset(forZ z: Float) -> TimeInterval {
        let layer: Int
        if z > 0.4 {
            layer = 0
        } else if z > 0 {
            layer = 1
        } else if z > -0.4 {
            layer = 2
        } else {
            layer = 3
        }
        return TimeInterval(layer) * layerDelayStep
    }
}

enum WeatherSunTapAudioCore {
    static let resetInterval: TimeInterval = 0.5
    static let brightVolume: Float = 0.36
    static let mediumVolume: Float = 0.28
    static let softVolume: Float = 0.20
    static let maxConcurrentSunTapPlayers = 1
    static let sfxIndexRange: ClosedRange<Int> = 1...7

    static func sfxName(for index: Int) -> String {
        let clamped = min(max(index, sfxIndexRange.lowerBound), sfxIndexRange.upperBound)
        return String(format: "sfx_%03d", clamped)
    }

    static func volume(forClickCount count: Int) -> Float {
        switch count {
        case 1...2:
            return brightVolume
        case 3...4:
            return mediumVolume
        default:
            return softVolume
        }
    }

    static func nextClickCount(previousCount: Int, lastTapTime: TimeInterval, now: TimeInterval) -> Int {
        guard lastTapTime > 0 else { return 1 }
        if now - lastTapTime > resetInterval {
            return 1
        }
        return previousCount + 1
    }

    static func audioURL(name: String, bundle: Bundle, fileManager: FileManager) -> URL? {
        let folder = "WeatherData/Audio"
        for ext in ["m4a", "mp3"] {
            let direct = bundle.bundleURL.appendingPathComponent("\(folder)/\(name).\(ext)")
            if fileManager.fileExists(atPath: direct.path) {
                return direct
            }
            if let bundled = bundle.url(forResource: name, withExtension: ext, subdirectory: folder) {
                return bundled
            }
        }
        return nil
    }

    static func audioURL(name: String, baseDirectory: URL, fileManager: FileManager) -> URL? {
        for ext in ["m4a", "mp3"] {
            let candidate = baseDirectory.appendingPathComponent("\(name).\(ext)")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}

enum WeatherSunDetailTapBurstCore {
    static let rayCount: Int = WeatherSunBurstCore.rayCount
    /// Total duration from start to when head and tail converge
    static let totalDuration: TimeInterval = 1.0
    /// Fraction of totalDuration after which tail starts moving (0.0–1.0)
    static let tailStartFraction: Double = 0.30
    static let staggerStep: TimeInterval = 0.012
    static let tapRayMinLength: Float = 0.09
    static let tapRayMaxLength: Float = 0.36
    static let tapRayThickness: Float = 0.073
    /// Min distance from sun center for inner edge at t=0
    static let tapMinStartOffset: Float = 2.1
    static let tapMaxStartOffset: Float = 2.7
    /// Total travel distance of each tip
    static let tapOutwardDistance: Float = 0.7
    static let crossScale: Float = 0.42
    /// Z offset from sun center toward camera so overlay renders in front
    static let overlayZOffset: Float = 1.5
    /// Z variation range for subtle per-ray depth jitter
    static let minZVariation: Float = -0.05
    static let maxZVariation: Float = 0.05
    /// Elevation angle range (radians) from XY plane toward camera (+Z)
    static let tapMinElevation: Float = 0.20   // ~11°
    static let tapMaxElevation: Float = 1.45   // ~83°, includes near z-axis shots

    /// Grayscale: closer to camera (higher z) = darker
    static func grayscale(forZVariation z: Float) -> Float {
        let normalized = (z - minZVariation) / (maxZVariation - minZVariation)
        return 0.72 - normalized * 0.54   // 0.72 (behind) → 0.18 (front)
    }

    static func easeOut(_ t: Double) -> Double {
        1.0 - pow(1.0 - min(max(t, 0.0), 1.0), 3)
    }

    static func planarDirection(index: Int, totalCount: Int) -> (x: Float, y: Float, z: Float) {
        let safeTotalCount = max(totalCount, 1)
        let progress = Float(index) / Float(safeTotalCount)
        let angle = progress * Float.pi * 2
        return (cos(angle), sin(angle), 0)
    }
}
