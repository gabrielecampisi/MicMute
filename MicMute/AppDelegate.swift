import Cocoa
import CoreAudio
import HotKey
import ServiceManagement
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var currentDeviceID: AudioDeviceID = 0
    private var inputDevices: [AudioInputDevice] = []
    
    private var observedDevices: Set<AudioDeviceID> = []
    private var startAtLoginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        self.initializeAudioEngine()
    }

    private func initializeAudioEngine() {
        self.inputDevices = fetchUniqueInputDevices()
        self.currentDeviceID = getDefaultInputDeviceID()
        
        DispatchQueue.main.async {
            self.setupStatusItem()
            self.setupHotKey()
            self.updateMenuAndIcon()
            self.observeGlobalChanges()
            self.refreshMuteObservers()
        }
    }

    // MARK: - Privacy & Permissions
    private func checkMicrophonePermissions(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    // MARK: - UI & Menu Bar
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "mic_on")
            button.image?.isTemplate = true
            
            // Fix Animazione Centrata
            button.wantsLayer = true
            if let layer = button.layer {
                layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                let bBounds = button.bounds
                layer.position = CGPoint(x: bBounds.midX, y: bBounds.midY)
            }
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Mute (⌘⇧M)", action: #selector(toggleMute), keyEquivalent: ""))
        menu.addItem(.separator())

        let inputMenu = NSMenu()
        for device in inputDevices {
            let item = NSMenuItem(title: device.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.representedObject = device.id
            item.state = (device.id == currentDeviceID) ? .on : .off
            inputMenu.addItem(item)
        }
        
        let inputDevicesItem = NSMenuItem(title: "Input Device", action: nil, keyEquivalent: "")
        inputDevicesItem.submenu = inputMenu
        menu.addItem(inputDevicesItem)
        menu.addItem(.separator())

        startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        menu.addItem(startAtLoginItem)
        
        menu.addItem(.separator())
        
        // --- SEZIONE VERSIONE ---
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionItem = NSMenuItem(title: "Version \(version) (Build \(build))", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        // ------------------------

        menu.addItem(NSMenuItem(title: "Quit MicMute", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        syncStartAtLoginMenuState()
    }

    // MARK: - Audio Engine
    @objc private func toggleMute() {
        let status = getMuteStatus(for: currentDeviceID)
        setSystemMicMuted(currentDeviceID, muted: !status.sw)
        updateMenuAndIcon()
    }

    private func setSystemMicMuted(_ device: AudioDeviceID, muted: Bool) {
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        for channel in 0...8 {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: AudioObjectPropertyElement(channel)
            )
            if AudioObjectHasProperty(device, &addr) {
                AudioObjectSetPropertyData(device, &addr, 0, nil, size, &value)
            }
        }
    }

    private func getMuteStatus(for device: AudioDeviceID) -> (hw: Bool, sw: Bool) {
        var sw: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &sw) != noErr {
            addr.mElement = 1
            AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &sw)
        }
        return (hw: false, sw: sw == 1)
    }

    private func updateMenuAndIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem.button else { return }
            let status = self.getMuteStatus(for: self.currentDeviceID)
            
            button.image = NSImage(named: status.sw ? "mic_off" : "mic_on")
            button.image?.isTemplate = !status.sw
            
            self.animateIcon()
            self.buildMenu()
        }
    }

    private func animateIcon() {
        guard let button = statusItem.button, let layer = button.layer else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.9
        animation.toValue = 1.1
        animation.duration = 0.12
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "pulse")
    }

    // MARK: - Observers
    private func observeGlobalChanges() {
        var addrDefault = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addrDefault, .main) { [weak self] _, _ in
            self?.currentDeviceID = self?.getDefaultInputDeviceID() ?? 0
            self?.updateMenuAndIcon()
        }

        var addrDevices = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addrDevices, .main) { [weak self] _, _ in
            self?.inputDevices = fetchUniqueInputDevices()
            self?.refreshMuteObservers()
            self?.updateMenuAndIcon()
        }
    }

    private func refreshMuteObservers() {
        for device in inputDevices {
            if !observedDevices.contains(device.id) {
                var addr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                AudioObjectAddPropertyListenerBlock(device.id, &addr, .main) { [weak self] _, _ in
                    self?.updateMenuAndIcon()
                }
                observedDevices.insert(device.id)
            }
        }
    }

    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? AudioDeviceID {
            var idCopy = id
            let size = UInt32(MemoryLayout<AudioDeviceID>.size)
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &idCopy)
        }
    }

    private func setupHotKey() {
        hotKey = HotKey(key: .m, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in self?.toggleMute() }
    }

    private func syncStartAtLoginMenuState() {
        startAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func toggleStartAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { print("Login error: \(error)") }
        syncStartAtLoginMenuState()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

// MARK: - Modelli e Utility
struct AudioInputDevice {
    let id: AudioDeviceID
    let name: String
}

func fetchUniqueInputDevices() -> [AudioInputDevice] {
    var devices = [AudioInputDevice]()
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var ids = [AudioDeviceID](repeating: 0, count: count)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)

    var seenNames = Set<String>()
    for id in ids {
        if hasInputChannels(id) {
            let name = getDeviceName(id)
            if !seenNames.contains(name) {
                seenNames.insert(name)
                devices.append(AudioInputDevice(id: id, name: name))
            }
        }
    }
    return devices
}

private func hasInputChannels(_ id: AudioDeviceID) -> Bool {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
    let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
    defer { bufferList.deallocate() }
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, bufferList) == noErr else { return false }
    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
    return buffers.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
}

private func getDeviceName(_ id: AudioDeviceID) -> String {
    var name: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    if AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr {
        return name?.takeRetainedValue() as String? ?? "Unknown"
    }
    return "Unknown Device"
}
