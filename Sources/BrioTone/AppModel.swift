import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var state: CameraState = .cameraDefault
    @Published var device: CameraController.Device?
    @Published var presets: [Preset] = []
    @Published var applyOnLaunch: Bool {
        didSet { UserDefaults.standard.set(applyOnLaunch, forKey: "applyOnLaunch") }
    }
    @Published var statusText: String = "Buscando cámara…"

    private let controller = CameraController()
    private let store = PresetStore()
    private var applyWork: DispatchWorkItem?

    init() {
        applyOnLaunch = UserDefaults.standard.bool(forKey: "applyOnLaunch")
        presets = PresetStore.builtIns + store.loadUserPresets()
        refreshDevice(initial: true)
    }

    // MARK: - Device

    func refreshDevice(initial: Bool = false) {
        guard let controller else {
            statusText = "No se encontró uvc-util"
            return
        }
        Task.detached { [weak self] in
            let dev = controller.detectDevice()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.device = dev
                guard let dev else {
                    self.statusText = "No hay webcam UVC conectada"
                    return
                }
                self.statusText = dev.name
                if initial {
                    if self.applyOnLaunch, let last = self.store.loadLastState() {
                        self.state = last
                        controller.apply(last, on: dev)
                    } else {
                        // Reflect what the camera currently has.
                        self.state = controller.readState(on: dev)
                    }
                }
            }
        }
    }

    // MARK: - Live apply (debounced)

    /// Call on every slider change. Pushes only the changed control immediately
    /// for responsiveness, and persists the state shortly after.
    func liveSet(_ control: CameraController.Control, _ value: Int) {
        guard let controller, let device else { return }
        Task.detached { controller.set(control, to: value, on: device) }
        scheduleSave()
    }

    func setAutoWhiteBalance(_ on: Bool) {
        guard let controller, let device else { return }
        state.autoWhiteBalance = on
        let wb = state.whiteBalance
        Task.detached {
            controller.setAutoWhiteBalance(on, on: device)
            if !on { controller.set(.whiteBalance, to: wb, on: device) }
        }
        scheduleSave()
    }

    func setAutoExposure(_ on: Bool) {
        guard let controller, let device else { return }
        state.autoExposure = on
        let (exp, gain) = (state.exposureTime, state.gain)
        Task.detached {
            controller.setAutoExposure(on, on: device)
            if !on {
                controller.set(.exposureTime, to: exp, on: device)
                controller.set(.gain, to: gain, on: device)
            }
        }
        scheduleSave()
    }

    func setAutoFocus(_ on: Bool) {
        guard let controller, let device else { return }
        state.autoFocus = on
        let focus = state.focus
        Task.detached {
            controller.setAutoFocus(on, on: device)
            if !on { controller.set(.focus, to: focus, on: device) }
        }
        scheduleSave()
    }

    func setBacklightCompensation(_ on: Bool) {
        guard let controller, let device else { return }
        state.backlightCompensation = on
        Task.detached { controller.set(.backlightCompensation, to: on ? 1 : 0, on: device) }
        scheduleSave()
    }

    func setPanTilt(pan: Int, tilt: Int) {
        guard let controller, let device else { return }
        state.pan = pan; state.tilt = tilt
        Task.detached { controller.setPanTilt(pan: pan, tilt: tilt, on: device) }
        scheduleSave()
    }

    /// Apply a complete state (used by presets).
    func applyState(_ newState: CameraState) {
        guard let controller, let device else { return }
        state = newState
        Task.detached { controller.apply(newState, on: device) }
        store.saveLastState(newState)
    }

    private func scheduleSave() {
        applyWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.store.saveLastState(self.state)
        }
        applyWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: - Presets

    func saveCurrentAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let idx = presets.firstIndex(where: { $0.name == trimmed && !$0.builtIn }) {
            presets[idx].state = state
        } else {
            presets.append(Preset(name: trimmed, state: state))
        }
        store.saveUserPresets(presets)
    }

    func deletePreset(_ preset: Preset) {
        guard !preset.builtIn else { return }
        presets.removeAll { $0.id == preset.id }
        store.saveUserPresets(presets)
    }

    func resetToCameraDefault() {
        applyState(.cameraDefault)
    }
}
