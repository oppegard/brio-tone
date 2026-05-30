import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var newPresetName = ""
    @State private var showingSave = false
    @State private var tab: Tab = .color

    enum Tab: String, CaseIterable, Identifiable {
        case color = "Color", exposure = "Exposición", frame = "Encuadre"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            presetRow
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            switch tab {
            case .color: colorSection
            case .exposure: exposureSection
            case .frame: frameSection
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 330)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "camera.aperture")
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("BrioTone").font(.headline)
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(model.device == nil ? .red : .secondary)
            }
            Spacer()
            Button { model.refreshDevice() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Volver a buscar la cámara")
        }
    }

    // MARK: - Presets

    private var presetRow: some View {
        HStack {
            Menu {
                ForEach(model.presets) { preset in
                    Button(preset.name) { model.applyState(preset.state) }
                }
                if model.presets.contains(where: { !$0.builtIn }) {
                    Divider()
                    Menu("Eliminar preset…") {
                        ForEach(model.presets.filter { !$0.builtIn }) { preset in
                            Button(preset.name, role: .destructive) { model.deletePreset(preset) }
                        }
                    }
                }
            } label: {
                Label("Cargar preset", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .disabled(model.device == nil)

            Spacer()

            Button {
                showingSave.toggle()
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("Guardar ajustes actuales como preset")
            .popover(isPresented: $showingSave, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre del preset").font(.caption).foregroundStyle(.secondary)
                    TextField("Ej. Llamada día", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit(save)
                    Button("Guardar", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
            }
        }
    }

    private func save() {
        model.saveCurrentAsPreset(named: newPresetName)
        newPresetName = ""
        showingSave = false
    }

    // MARK: - Color section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            whiteBalanceSection
            sliderRow("Saturación", value: $model.state.saturation, control: .saturation, range: 0...255)
            sliderRow("Contraste", value: $model.state.contrast, control: .contrast, range: 0...255)
            sliderRow("Nitidez", value: $model.state.sharpness, control: .sharpness, range: 0...255)
            sliderRow("Brillo", value: $model.state.brightness, control: .brightness, range: 0...255)
        }
    }

    private var whiteBalanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Balance de blancos").font(.subheadline.weight(.medium))
                Spacer()
                Toggle("Auto", isOn: Binding(
                    get: { model.state.autoWhiteBalance },
                    set: { model.setAutoWhiteBalance($0) }
                ))
                .toggleStyle(.switch).controlSize(.mini)
            }
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { Double(model.state.whiteBalance) },
                    set: { v in model.state.whiteBalance = Int(v); model.liveSet(.whiteBalance, Int(v)) }
                ), in: 2800...7500)
                Text("\(model.state.whiteBalance) K")
                    .font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
            }
            .disabled(model.state.autoWhiteBalance || model.device == nil)
            Text("↑ número = más cálido en esta cámara. Ajusta mirando el vídeo en vivo.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Exposure section

    private var exposureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Exposición").font(.subheadline.weight(.medium))
                Spacer()
                Toggle("Auto", isOn: Binding(
                    get: { model.state.autoExposure },
                    set: { model.setAutoExposure($0) }
                ))
                .toggleStyle(.switch).controlSize(.mini)
            }
            shutterRow
            sliderRow("ISO", value: $model.state.gain, control: .gain,
                      range: 0...255, disabledExtra: model.state.autoExposure)
            Toggle("Compensar contraluz", isOn: Binding(
                get: { model.state.backlightCompensation },
                set: { model.setBacklightCompensation($0) }
            ))
            .toggleStyle(.switch).controlSize(.mini).font(.subheadline)
            HStack {
                Text("Anti-parpadeo").font(.subheadline)
                Spacer()
                Picker("", selection: Binding(
                    get: { model.state.powerLine },
                    set: { v in model.state.powerLine = v; model.liveSet(.powerLine, v) }
                )) {
                    Text("50 Hz").tag(1); Text("60 Hz").tag(2)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 130)
            }
            Text("Bloquea Auto y fija obturador + ISO para una imagen estable, sin \"bombeo\".")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// Shutter shown as a 1/x second fraction (exposure-time-abs is in 0.1 ms).
    private var shutterRow: some View {
        HStack(spacing: 8) {
            Text("Obturador").font(.subheadline).frame(width: 78, alignment: .leading)
            Slider(value: Binding(
                get: { Double(model.state.exposureTime) },
                set: { v in model.state.exposureTime = Int(v); model.liveSet(.exposureTime, Int(v)) }
            ), in: 3...2047)
            Text(shutterLabel(model.state.exposureTime))
                .font(.caption.monospacedDigit()).frame(width: 46, alignment: .trailing)
        }
        .disabled(model.state.autoExposure || model.device == nil)
    }

    private func shutterLabel(_ v: Int) -> String {
        let seconds = Double(v) / 10000.0           // 0.1 ms units
        guard seconds > 0 else { return "—" }
        return "1/\(Int((1.0 / seconds).rounded()))"
    }

    // MARK: - Focus & framing section

    private var frameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Enfoque").font(.subheadline.weight(.medium))
                Spacer()
                Toggle("Auto", isOn: Binding(
                    get: { model.state.autoFocus },
                    set: { model.setAutoFocus($0) }
                ))
                .toggleStyle(.switch).controlSize(.mini)
            }
            sliderRow("Distancia", value: $model.state.focus, control: .focus,
                      range: 0...255, disabledExtra: model.state.autoFocus)
            zoomRow
            if model.state.zoom > 100 {
                panTiltRow("Pan", value: model.state.pan) { model.setPanTilt(pan: $0, tilt: model.state.tilt) }
                panTiltRow("Tilt", value: model.state.tilt) { model.setPanTilt(pan: model.state.pan, tilt: $0) }
            } else {
                Text("Sube el zoom para reencuadrar con pan/tilt.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var zoomRow: some View {
        HStack(spacing: 8) {
            Text("Zoom").font(.subheadline).frame(width: 78, alignment: .leading)
            Slider(value: Binding(
                get: { Double(model.state.zoom) },
                set: { v in model.state.zoom = Int(v); model.liveSet(.zoom, Int(v)) }
            ), in: 100...400, step: 5)
            Text(String(format: "%.1f×", Double(model.state.zoom) / 100.0))
                .font(.caption.monospacedDigit()).frame(width: 46, alignment: .trailing)
        }
        .disabled(model.device == nil)
    }

    private func panTiltRow(_ title: String, value: Int, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline).frame(width: 78, alignment: .leading)
            Slider(value: Binding(
                get: { Double(value) },
                set: { set(Int(($0 / 3600).rounded()) * 3600) }
            ), in: -72000...72000, step: 3600)
            Text("\(value / 3600)").font(.caption.monospacedDigit())
                .frame(width: 46, alignment: .trailing)
        }
        .disabled(model.device == nil)
    }

    // MARK: - Generic slider row

    private func sliderRow(_ title: String,
                           value: Binding<Int>,
                           control: CameraController.Control,
                           range: ClosedRange<Int>,
                           disabledExtra: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline).frame(width: 78, alignment: .leading)
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { v in value.wrappedValue = Int(v); model.liveSet(control, Int(v)) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            Text("\(value.wrappedValue)").font(.caption.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
        .disabled(model.device == nil || disabledExtra)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Toggle("Aplicar mis ajustes al iniciar sesión", isOn: $model.applyOnLaunch)
                .toggleStyle(.switch).controlSize(.mini).font(.caption)
            HStack {
                Button("Restablecer Logitech") { model.resetToCameraDefault() }
                    .controlSize(.small).disabled(model.device == nil)
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }.controlSize(.small)
            }
        }
    }
}
