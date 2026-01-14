//
//  OSDManager.swift
//  MicMute
//
//  Created by Gabriele Campisi on 2025.
//  Copyright © 2025 Gabriele Campisi. All rights reserved.
//
//  CREDITS:
//  - Lead Developer: Gabriele Campisi
//  - UI & UX Design: Gabriele Campisi
//  - Core Audio Integration: Gabriele Campisi
//  - HotKey Library: Global shortcuts management.
//
//  LICENSE:
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
import Cocoa

class OSDManager {
    private var window: NSPanel?
    private var timer: Timer?

    init() {}

    func show(message: String, imageName: String) {
        timer?.invalidate()
        window?.orderOut(nil)

        let panelWidth: CGFloat = 240
        let panelHeight: CGFloat = 64
        
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
        panel.invalidateShadow()

        // --- CONTENITORE NERO (Sostituisce il Blur) ---
        let container = NSView(frame: panel.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        container.layer?.cornerRadius = panelHeight / 2
        container.layer?.masksToBounds = true
        
        // --- ICONA ---
        let imageView = NSImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(named: imageName) {
            image.isTemplate = true
            imageView.image = image
            if #available(macOS 10.14, *) {
                imageView.contentTintColor = .white
            }
        }
        
        imageView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        // --- TESTO ---
        let textField = NSTextField(labelWithString: message)
        textField.font = NSFont.systemFont(ofSize: 17, weight: .bold)
        textField.textColor = .white
        textField.translatesAutoresizingMaskIntoConstraints = false

        // --- ALLINEAMENTO ---
        let stackView = NSStackView(views: [imageView, textField])
        stackView.orientation = .horizontal
        stackView.spacing = 12
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stackView)
        panel.contentView = container

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        // --- POSIZIONAMENTO E ANIMAZIONE SLIDE-IN ---
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (panelWidth / 2)
            let y = screenRect.minY + 60
            
            panel.setFrameOrigin(NSPoint(x: x, y: y - 15))
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1.0
                panel.animator().setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        self.window = panel

        timer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: false) { [weak self] _ in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self?.window?.animator().alphaValue = 0
            }, completionHandler: {
                self?.window?.orderOut(nil)
                self?.window = nil
            })
        }
    }
}
