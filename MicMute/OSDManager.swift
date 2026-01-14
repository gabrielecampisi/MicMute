import Cocoa

class OSDManager {
    private var window: NSPanel?
    private var timer: Timer?

    init() {}

    func show(message: String, imageName: String) {
        timer?.invalidate()
        window?.orderOut(nil)

        // Dimensioni: stile pillola moderna
        let panelWidth: CGFloat = 240
        let panelHeight: CGFloat = 70
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .mainMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let container = NSView(frame: panel.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        container.layer?.cornerRadius = panelHeight / 2 // Effetto pillola
        container.layer?.masksToBounds = true

        // 1. Configurazione Icona
        let imageView = NSImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(named: imageName) {
            image.isTemplate = true
            imageView.image = image
            if #available(macOS 10.14, *) {
                imageView.contentTintColor = .white
            }
        }
        
        // Vincoli dimensionali icona
        imageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 30).isActive = true

        // 2. Configurazione Testo
        let textField = NSTextField(labelWithString: message)
        textField.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        textField.textColor = .white
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.drawsBackground = false
        textField.isBordered = false

        // 3. StackView per allineamento perfetto
        let stackView = NSStackView(views: [imageView, textField])
        stackView.orientation = .horizontal
        stackView.spacing = 12
        stackView.alignment = .centerY // Questo garantisce l'allineamento verticale
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stackView)
        panel.contentView = container

        // Centratura della StackView nel pannello
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        // Posizionamento in fondo allo schermo
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (panelWidth / 2)
            let y = screenRect.minY + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        panel.alphaValue = 0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        self.window = panel

        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                self?.window?.animator().alphaValue = 0
            }, completionHandler: {
                self?.window?.orderOut(nil)
                self?.window = nil
            })
        }
    }
}

