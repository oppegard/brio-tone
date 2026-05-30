import Foundation

/// Thin wrapper around the bundled `uvc-util` binary that reads and writes the
/// UVC sensor controls of a connected Logitech-class webcam (built/verified
/// against the MX Brio, 0x046d:0x0944).
final class CameraController {

    struct Device: Equatable {
        let vidpid: String   // e.g. "0x046d:0x0944"
        let name: String     // e.g. "MX Brio"
    }

    /// Native ranges reported by the MX Brio. Used to clamp and to map sliders.
    enum Control: String, CaseIterable {
        case whiteBalance = "white-balance-temp"
        case autoWhiteBalance = "auto-white-balance-temp"
        case saturation
        case contrast
        case sharpness
        case brightness
        case exposureMode = "auto-exposure-mode"
        case exposureTime = "exposure-time-abs"
        case gain
        case backlightCompensation = "backlight-compensation"
        case powerLine = "power-line-frequency"
        case autoFocus = "auto-focus"
        case focus = "focus-abs"
        case zoom = "zoom-abs"

        var range: ClosedRange<Int> {
            switch self {
            case .whiteBalance: return 2800...7500
            case .saturation, .contrast, .sharpness, .brightness,
                 .gain, .focus: return 0...255
            case .autoWhiteBalance, .autoFocus, .backlightCompensation: return 0...1
            case .exposureMode: return 1...8
            case .exposureTime: return 3...2047
            case .powerLine: return 1...2
            case .zoom: return 100...400
            }
        }
    }

    /// UVC auto-exposure-mode bitmap values used on the MX Brio.
    enum ExposureMode: Int { case manual = 1, aperturePriority = 8 }

    private let binaryURL: URL

    init?() {
        guard let url = CameraController.locateBinary() else { return nil }
        self.binaryURL = url
    }

    // MARK: - Binary discovery

    private static func locateBinary() -> URL? {
        // Inside the assembled .app: Contents/Resources/uvc-util
        if let res = Bundle.main.resourceURL?.appendingPathComponent("uvc-util"),
           FileManager.default.isExecutableFile(atPath: res.path) {
            return res
        }
        // Dev fallback: running via `swift run` from the package root.
        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/uvc-util")
        if FileManager.default.isExecutableFile(atPath: dev.path) { return dev }
        return nil
    }

    // MARK: - Process helper

    @discardableResult
    private func run(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = binaryURL
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Device discovery

    /// Returns the first UVC device reported by `uvc-util -d`. The built-in
    /// MacBook camera and Continuity iPhone camera are not UVC, so an external
    /// webcam is normally the only entry.
    func detectDevice() -> Device? {
        let out = run(["-d"])
        for line in out.split(separator: "\n") {
            // Data rows look like: "0   0x046d:0x0944   0x00100000   1.00   MX Brio"
            guard let match = line.range(of: #"0x[0-9a-fA-F]{4}:0x[0-9a-fA-F]{4}"#,
                                         options: .regularExpression) else { continue }
            let vidpid = String(line[match])
            // Name is everything after the UVC version token at the end.
            let cols = line.split(whereSeparator: { $0 == " " }).map(String.init)
            let name = cols.count >= 5 ? cols[4...].joined(separator: " ") : "Webcam"
            return Device(vidpid: vidpid, name: name)
        }
        return nil
    }

    // MARK: - Read / write

    func get(_ control: Control, on device: Device) -> Int? {
        let out = run(["-V", device.vidpid, "-o", control.rawValue])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if out == "true" { return 1 }
        if out == "false" { return 0 }
        return Int(out)
    }

    func set(_ control: Control, to value: Int, on device: Device) {
        let clamped = min(max(value, control.range.lowerBound), control.range.upperBound)
        run(["-V", device.vidpid, "-s", "\(control.rawValue)=\(clamped)"])
    }

    func setAutoWhiteBalance(_ on: Bool, on device: Device) {
        run(["-V", device.vidpid, "-s", "auto-white-balance-temp=\(on ? "true" : "false")"])
    }

    func setAutoExposure(_ on: Bool, on device: Device) {
        let mode = on ? ExposureMode.aperturePriority : .manual
        run(["-V", device.vidpid, "-s", "auto-exposure-mode=\(mode.rawValue)"])
    }

    func setAutoFocus(_ on: Bool, on device: Device) {
        run(["-V", device.vidpid, "-s", "auto-focus=\(on ? "true" : "false")"])
    }

    func setPanTilt(pan: Int, tilt: Int, on device: Device) {
        run(["-V", device.vidpid, "-s", "pan-tilt-abs={pan=\(pan),tilt=\(tilt)}"])
    }

    private func getPanTilt(on device: Device) -> (Int, Int)? {
        let out = run(["-V", device.vidpid, "-o", "pan-tilt-abs"])
        let nums = out.matches(of: #/-?\d+/#).compactMap { Int($0.output) }
        return nums.count >= 2 ? (nums[0], nums[1]) : nil
    }

    /// Applies a whole state. Some "auto" controls must be turned off before
    /// their manual counterparts will stick, so order matters here.
    func apply(_ state: CameraState, on device: Device) {
        // Color
        setAutoWhiteBalance(state.autoWhiteBalance, on: device)
        if !state.autoWhiteBalance { set(.whiteBalance, to: state.whiteBalance, on: device) }
        set(.saturation, to: state.saturation, on: device)
        set(.contrast, to: state.contrast, on: device)
        set(.sharpness, to: state.sharpness, on: device)
        set(.brightness, to: state.brightness, on: device)
        // Exposure
        setAutoExposure(state.autoExposure, on: device)
        if !state.autoExposure {
            set(.exposureTime, to: state.exposureTime, on: device)
            set(.gain, to: state.gain, on: device)
        }
        set(.backlightCompensation, to: state.backlightCompensation ? 1 : 0, on: device)
        set(.powerLine, to: state.powerLine, on: device)
        // Focus & framing
        setAutoFocus(state.autoFocus, on: device)
        if !state.autoFocus { set(.focus, to: state.focus, on: device) }
        set(.zoom, to: state.zoom, on: device)
        setPanTilt(pan: state.pan, tilt: state.tilt, on: device)
    }

    /// Reads the device's current values into a CameraState.
    func readState(on device: Device) -> CameraState {
        var s = CameraState.cameraDefault
        if let v = get(.autoWhiteBalance, on: device) { s.autoWhiteBalance = (v == 1) }
        if let v = get(.whiteBalance, on: device) { s.whiteBalance = v }
        if let v = get(.saturation, on: device) { s.saturation = v }
        if let v = get(.contrast, on: device) { s.contrast = v }
        if let v = get(.sharpness, on: device) { s.sharpness = v }
        if let v = get(.brightness, on: device) { s.brightness = v }
        if let v = get(.exposureMode, on: device) { s.autoExposure = (v != ExposureMode.manual.rawValue) }
        if let v = get(.exposureTime, on: device) { s.exposureTime = v }
        if let v = get(.gain, on: device) { s.gain = v }
        if let v = get(.backlightCompensation, on: device) { s.backlightCompensation = (v == 1) }
        if let v = get(.powerLine, on: device) { s.powerLine = v }
        if let v = get(.autoFocus, on: device) { s.autoFocus = (v == 1) }
        if let v = get(.focus, on: device) { s.focus = v }
        if let v = get(.zoom, on: device) { s.zoom = v }
        if let (p, t) = getPanTilt(on: device) { s.pan = p; s.tilt = t }
        return s
    }
}
