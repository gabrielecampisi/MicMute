//
//  MicMinuteApp.swift
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
import SwiftUI
import HotKey
import CoreAudio
import ServiceManagement

@main
struct MicMinuteApp: App {
    // Collega l'AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // Nessuna finestra principale
        }
    }
}
