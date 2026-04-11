import Foundation

// MARK: - SceneNode Name Constants
// All SCNNode names used across WeatherSceneManager and DimensionSceneBuilder.
// Using constants avoids typo-bugs when looking up nodes by name.

enum SceneNode {

    // MARK: Page A — Main Weather Scene
    static let sun           = "weather_sun"
    static let temperature   = "weather_temperature"
    static let birds         = "weather_birds"
    static let sunBurst      = "weather_sun_burst"
    static let sunTitle      = "weather_sun_title"
    static let cloudMain     = "weather_cloud_main"
    static let cloudLeft     = "weather_cloud_left"
    static let cloudRight    = "weather_cloud_right"
    static let bolt          = "weather_bolt"
    static let precipitation = "weather_precip"

    // MARK: Lighting
    static let ambientLight  = "light_ambient"
    static let sunLight      = "light_sun"
    static let thunderLight  = "light_thunder"

    // MARK: Page B — Dimension Scenes
    static let dimRoot        = "dim_root"
    static let dimSun         = "dim_sun"
    static let dimCloud       = "dim_cloud"
    static let dimWindStreams  = "dim_wind_streams"
    static let dimRain        = "dim_rain"
    static let dimAirParticle = "dim_air_particle"
}
