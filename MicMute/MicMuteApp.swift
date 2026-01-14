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
