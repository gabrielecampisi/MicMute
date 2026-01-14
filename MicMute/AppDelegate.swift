import Cocoa
import CoreAudio
import HotKey
import ServiceManagement
import AVFoundation

// MARK: - Modelli
struct AudioInputDevice {
    let id: AudioDeviceID
    let name: String
}

private struct RegisteredListener {
    let deviceID: AudioDeviceID
    let address: AudioObjectPropertyAddress
    let block: AudioObjectPropertyListenerBlock
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var currentDeviceID: AudioDeviceID = 0
    private var inputDevices: [AudioInputDevice] = []
    
    // Gestione Listener
    private var activeMuteListeners: [RegisteredListener] = []
    private var globalDeviceListener: RegisteredListener?
    
    private let osd = OSDManager()

    private var isOSDEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isOSDEnabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "isOSDEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isOSDEnabled")
        }
    }

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
            self.observeGlobalChanges()
            self.refreshMuteObservers()
            self.updateMenuAndIcon()
        }
    }

    // MARK: - Core Audio: Recupero Dati
    private func fetchUniqueInputDevices() -> [AudioInputDevice] {
        var deviceList = [AudioInputDevice]()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var size: UInt32 = 0
        let _ = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        
        guard status == noErr else { return deviceList }
        
        for id in ids {
            var streamAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize)
            
            if streamSize > 0 {
                var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
                var deviceName: Unmanaged<CFString>?
                var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
                
                let nameStatus = AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &deviceName)
                let name = (nameStatus == noErr && deviceName != nil)
                    ? (deviceName!.takeRetainedValue() as String)
                    : "Unknown Device (\(id))"
                
                deviceList.append(AudioInputDevice(id: id, name: name))
            }
        }
        return deviceList
    }

    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    private func getMuteStatus(for device: AudioDeviceID) -> Bool {
        var sw: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        
        guard AudioObjectHasProperty(device, &addr) else { return false }
        AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &sw)
        return sw == 1
    }

    // MARK: - Core Audio: Gestione Listener (Sicura)
    private func observeGlobalChanges() {
        if let existing = globalDeviceListener {
            var addr = existing.address
            AudioObjectRemovePropertyListenerBlock(existing.deviceID, &addr, .main, existing.block)
        }

        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.currentDeviceID = self.getDefaultInputDeviceID()
            self.refreshMuteObservers()
            self.updateMenuAndIcon()
        }

        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main, block) == noErr {
            globalDeviceListener = RegisteredListener(deviceID: AudioObjectID(kAudioObjectSystemObject), address: addr, block: block)
        }
    }

    private func refreshMuteObservers() {
        removeAllMuteObservers()
        var muteAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)

        for device in inputDevices {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                self?.updateMenuAndIcon()
            }
            if AudioObjectAddPropertyListenerBlock(device.id, &muteAddress, .main, block) == noErr {
                activeMuteListeners.append(RegisteredListener(deviceID: device.id, address: muteAddress, block: block))
            }
        }
    }

    private func removeAllMuteObservers() {
        for listener in activeMuteListeners {
            var addr = listener.address
            AudioObjectRemovePropertyListenerBlock(listener.deviceID, &addr, .main, listener.block)
        }
        activeMuteListeners.removeAll()
    }

    // MARK: - UI & Status Item Logic
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            // Registriamo sia il click sinistro che quello destro
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        // Se è click destro o Click sinistro + tasto Control
        if event?.type == .rightMouseUp || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true) {
            statusItem.menu = buildMenu() // Assegna il menu temporaneamente
            statusItem.button?.performClick(nil) // Forza l'apertura
            statusItem.menu = nil // Lo rimuove subito dopo per ripristinare il click sinistro
        } else {
            toggleMute()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        let muteItem = NSMenuItem(title: "Toggle Mute", action: #selector(toggleMute), keyEquivalent: "m")
        muteItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(muteItem)
        
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

        let startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        startAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(startAtLoginItem)
        
        let osdItem = NSMenuItem(title: "Show On-Screen Display", action: #selector(toggleOSDSetting), keyEquivalent: "")
        osdItem.state = isOSDEnabled ? .on : .off
        menu.addItem(osdItem)
        
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Donate & Support ❤️", action: #selector(openDonateLink), keyEquivalent: ""))
        
        menu.addItem(.separator())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionItem = NSMenuItem(title: "Version \(version) (Build \(build))", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem(title: "Quit MicMute", action: #selector(quitApp), keyEquivalent: "q"))

        return menu
    }

    private func updateMenuAndIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem.button else { return }
            let isMuted = self.getMuteStatus(for: self.currentDeviceID)
            
            let iconName = isMuted ? "mic_off" : "mic_on"
            let icon = NSImage(named: iconName)
            
            icon?.isTemplate = !isMuted
            button.image = icon
            self.animateIcon()
        }
    }

    private func setupHotKey() {
        self.hotKey = HotKey(key: .m, modifiers: [.command, .shift])
        self.hotKey?.keyDownHandler = { [weak self] in self?.toggleMute() }
    }

    // MARK: - Azioni
    @objc private func toggleMute() {
        let currentlyMuted = getMuteStatus(for: currentDeviceID)
        var newState: UInt32 = currentlyMuted ? 0 : 1
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(currentDeviceID, &addr) {
            let size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectSetPropertyData(currentDeviceID, &addr, 0, nil, size, &newState)
        }
        
        if isOSDEnabled {
            osd.show(message: !currentlyMuted ? "MUTED" : "UNMUTED", imageName: !currentlyMuted ? "mic_off" : "mic_on")
        }
        updateMenuAndIcon()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? AudioDeviceID {
            currentDeviceID = id
            refreshMuteObservers()
            updateMenuAndIcon()
        }
    }

    private func animateIcon() {
        guard let button = statusItem.button, let layer = button.layer else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.9
        animation.toValue = 1.1
        animation.duration = 0.1
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "pulse")
    }

    @objc private func toggleOSDSetting() { isOSDEnabled = !isOSDEnabled }
    
    @objc private func openDonateLink() {
        if let url = URL(string: "https://www.paypal.com/donate/?business=8YZFY5HJMKQC2&no_recurring=0&currency_code=EUR") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleStartAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { print(error) }
    }

    @objc private func quitApp() {
        removeAllMuteObservers()
        NSApp.terminate(nil)
    }
}
