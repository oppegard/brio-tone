import Foundation

/// A full snapshot of the sensor controls we expose. Default property values
/// double as the MX Brio's factory defaults and provide backward-compatible
/// decoding for presets saved by older versions (see `init(from:)`).
struct CameraState: Codable, Equatable {
    // Color
    var autoWhiteBalance = true
    var whiteBalance = 5000     // 2800...7500 K
    var saturation = 128        // 0...255
    var contrast = 128          // 0...255
    var sharpness = 128         // 0...255
    var brightness = 128        // 0...255
    // Exposure
    var autoExposure = true
    var exposureTime = 156      // 3...2047 (units of 0.1 ms; shutter)
    var gain = 0                // 0...255 (ISO)
    var backlightCompensation = true
    var powerLine = 2           // 1 = 50 Hz, 2 = 60 Hz (anti-flicker)
    // Focus & framing
    var autoFocus = true
    var focus = 0               // 0...255
    var zoom = 100              // 100...400 (1x...4x)
    var pan = 0                 // -72000...72000
    var tilt = 0                // -72000...72000

    init(autoWhiteBalance: Bool = true, whiteBalance: Int = 5000,
         saturation: Int = 128, contrast: Int = 128, sharpness: Int = 128,
         brightness: Int = 128, autoExposure: Bool = true,
         exposureTime: Int = 156, gain: Int = 0,
         backlightCompensation: Bool = true, powerLine: Int = 2,
         autoFocus: Bool = true, focus: Int = 0, zoom: Int = 100,
         pan: Int = 0, tilt: Int = 0) {
        self.autoWhiteBalance = autoWhiteBalance
        self.whiteBalance = whiteBalance
        self.saturation = saturation
        self.contrast = contrast
        self.sharpness = sharpness
        self.brightness = brightness
        self.autoExposure = autoExposure
        self.exposureTime = exposureTime
        self.gain = gain
        self.backlightCompensation = backlightCompensation
        self.powerLine = powerLine
        self.autoFocus = autoFocus
        self.focus = focus
        self.zoom = zoom
        self.pan = pan
        self.tilt = tilt
    }

    /// Tolerant decoding: any key missing from older JSON falls back to its
    /// default, so previously saved presets keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func b(_ k: CodingKeys, _ d: Bool) -> Bool { (try? c.decodeIfPresent(Bool.self, forKey: k)) ?? nil ?? d }
        func i(_ k: CodingKeys, _ d: Int) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? nil ?? d }
        autoWhiteBalance = b(.autoWhiteBalance, true)
        whiteBalance = i(.whiteBalance, 5000)
        saturation = i(.saturation, 128)
        contrast = i(.contrast, 128)
        sharpness = i(.sharpness, 128)
        brightness = i(.brightness, 128)
        autoExposure = b(.autoExposure, true)
        exposureTime = i(.exposureTime, 156)
        gain = i(.gain, 0)
        backlightCompensation = b(.backlightCompensation, true)
        powerLine = i(.powerLine, 2)
        autoFocus = b(.autoFocus, true)
        focus = i(.focus, 0)
        zoom = i(.zoom, 100)
        pan = i(.pan, 0)
        tilt = i(.tilt, 0)
    }

    /// The MX Brio's factory defaults.
    static let cameraDefault = CameraState()

    /// A warmer, gentler starting point closer to Apple's rendering: fixed
    /// warm white balance, slightly lower saturation/contrast, much less of
    /// Logitech's aggressive sharpening, a touch brighter. Exposure/focus stay
    /// on auto — lock those live per your lighting. Tune from here.
    /// Empirically tuned: the MX Brio runs cold (auto sits near 4300 K and
    /// reads blue), so we push white balance warm to ~6500 K to counter it.
    static let appleish = CameraState(
        autoWhiteBalance: false, whiteBalance: 6500,
        saturation: 112, contrast: 120, sharpness: 92, brightness: 136
    )

    static let neutral = CameraState(
        autoWhiteBalance: false, whiteBalance: 5800,
        saturation: 120, contrast: 124, sharpness: 110, brightness: 130
    )

    // MARK: - Cinematic presets
    //
    // Shared cinematic DNA: locked white balance + locked exposure at a 1/60 s
    // shutter (the 180° rule at 30 fps → natural motion blur), low sharpness
    // (kills webcam over-sharpening), and a flatter, graded color base.
    // `gain` is the one value to match to YOUR room: raise it until well-lit,
    // keep it as low as possible for a clean, noise-free image. Calibrated
    // against Johan's room, where 1/60 s + low gain was already well exposed.

    /// Warm, clean, flagship cinematic look for a well-lit room.
    static let cineWarm = CameraState(
        autoWhiteBalance: false, whiteBalance: 6200,
        saturation: 108, contrast: 110, sharpness: 78, brightness: 128,
        autoExposure: false, exposureTime: 167, gain: 40,
        backlightCompensation: false, powerLine: 2
    )

    /// Flat, neutral, "log-like" base — the most controlled / gradeable look.
    static let cineFlat = CameraState(
        autoWhiteBalance: false, whiteBalance: 5500,
        saturation: 100, contrast: 102, sharpness: 70, brightness: 130,
        autoExposure: false, exposureTime: 167, gain: 48,
        backlightCompensation: false, powerLine: 2
    )

    /// Moody low-key look for dim/evening light: punchy contrast, darker, with
    /// more gain (and a touch slower 1/50 s shutter) to gather light.
    static let cineLowKey = CameraState(
        autoWhiteBalance: false, whiteBalance: 5800,
        saturation: 106, contrast: 138, sharpness: 84, brightness: 116,
        autoExposure: false, exposureTime: 200, gain: 120,
        backlightCompensation: false, powerLine: 2
    )
}

/// A named, user-savable look.
struct Preset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var state: CameraState
    var builtIn: Bool

    init(id: UUID = UUID(), name: String, state: CameraState, builtIn: Bool = false) {
        self.id = id
        self.name = name
        self.state = state
        self.builtIn = builtIn
    }
}

/// Persists user presets and the "apply on launch" choice to
/// ~/Library/Application Support/BrioTone/.
final class PresetStore {
    private let dir: URL
    private let presetsURL: URL
    private let stateURL: URL

    static let builtIns: [Preset] = [
        Preset(name: "🎬 Cine — Cálido (1/60)", state: .cineWarm, builtIn: true),
        Preset(name: "🎬 Cine — Plano/Neutro", state: .cineFlat, builtIn: true),
        Preset(name: "🎬 Cine — Low Key (noche)", state: .cineLowKey, builtIn: true),
        Preset(name: "Apple-ish (cálido)", state: .appleish, builtIn: true),
        Preset(name: "Neutro", state: .neutral, builtIn: true),
        Preset(name: "Logitech (default)", state: .cameraDefault, builtIn: true),
    ]

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("BrioTone", isDirectory: true)
        presetsURL = dir.appendingPathComponent("presets.json")
        stateURL = dir.appendingPathComponent("last-state.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func loadUserPresets() -> [Preset] {
        guard let data = try? Data(contentsOf: presetsURL),
              let list = try? JSONDecoder().decode([Preset].self, from: data) else { return [] }
        return list
    }

    func saveUserPresets(_ presets: [Preset]) {
        let user = presets.filter { !$0.builtIn }
        if let data = try? JSONEncoder().encode(user) {
            try? data.write(to: presetsURL)
        }
    }

    func loadLastState() -> CameraState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(CameraState.self, from: data)
    }

    func saveLastState(_ state: CameraState) {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL)
        }
    }
}
