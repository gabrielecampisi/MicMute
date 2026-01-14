# MicMute 🎙️

**MicMute** is a lightweight and modern macOS utility designed by **Gabriele Campisi** to manage microphone muting directly from the menu bar or via global keyboard shortcuts.

The application is written in Swift and leverages low-level Core Audio APIs to ensure maximum compatibility with all input devices, including USB, Bluetooth, and built-in microphones.

## ✨ Features

- **Quick Toggle**: Left-click the menu bar icon to mute or unmute instantly.
- **Smart Iconography**: The icon turns **red** when muted and adapts to the system theme (Light/Dark mode) when the microphone is active.
- **Global Shortcut**: Use `Cmd + Shift + M` to toggle mute from any application.
- **Visual Feedback (OSD)**: Displays a native-looking On-Screen Display at the center of the screen whenever the status changes.
- **Multi-Device Management**: Easily select which microphone to control from the context menu (Right-click).
- **Launch at Login**: Built-in option to automatically start the app when you turn on your Mac.

## 🚀 Installation & Compilation

### Prerequisites
- macOS 13.0 or higher.
- Xcode 15.0+ (for compilation).
- [HotKey library](https://github.com/soffes/HotKey) (required dependency).

### Manual Build
1. Clone the repository.
2. Open `MicMute.xcodeproj` in Xcode.
3. Ensure the `mic_on` and `mic_off` icons are present in `Assets.xcassets`.
4. Select the **MicMute** target and press `Cmd + R` to build and run.



## 🛠 Technical Architecture

Developed by Gabriele Campisi, the app is built on a hardware-reactive architecture:
- **Core Audio Listeners**: Instead of constant polling, the app registers listeners that are triggered by the kernel only when the hardware status actually changes. This minimizes CPU usage.
- **SMAppService**: Utilizes Apple's modern framework for login persistence, avoiding legacy background scripts.
- **Event Interception**: Implements a custom `NSStatusItem` interaction model to distinguish between Left-click (action) and Right-click (menu).



## 📜 License

Copyright (c) 2026 Gabriele Campisi.
This project is licensed under the **GNU GPL v3**. See the `LICENSE` file for more details.

---
**Credits:** Developed with ❤️ by **Gabriele Campisi**.
If you find this tool useful, please consider a small donation via the link in the app menu.
