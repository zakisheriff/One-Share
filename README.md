# <div align="center">One Share</div>

<div align="center">
<strong>The Next-Generation Dual-Protocol File Transfer for macOS</strong>
</div>

<br />

<div align="center">

<img src="assets/badges/macos-tahoe.svg" height="50" />
<img src="assets/badges/swift.svg" height="50" />
<img src="assets/badges/license.svg" height="50" />

<br />

<a href="https://github.com/zakisheriff/OneShare/releases/latest">
<img src="assets/badges/download-dmg.svg" height="50" />
</a>

</div>

<br />

> **"It feels like it was built by Apple."**
>
> One Share isn't just a tool; it's a seamless extension of your Mac.  
> Designed with the fluid, glassy aesthetics of **macOS 26**, it bridges the gap between your Android & iOS devices and your Mac with elegance and speed.

---

## 🌟 Vision

One Share's purpose is to be:

- **A next-generation macOS file explorer** for Android & iOS
- **A beautifully native SwiftUI application** showcasing true Apple-level design
- **A fast, stable, modern alternative** to outdated file transfer tools

---

## ✨ Why One Share?

Forget the clunky, outdated file transfer tools of the past.  
One Share is built from the ground up to be **fast, beautiful, and truly native**.

---

## 🎨 Stunning "Liquid Glass" UI

- **Native Aesthetics**  
  Built with SwiftUI and designed to feel right at home on macOS Sequoia.

- **Unified Glass Window**  
  A seamless, translucent sidebar merging perfectly with the title bar.

- **Liquid Selection**  
  Files and folders highlight with a premium, rounded, blurred-glass glow.

- **Zero-Latency Interaction**  
  Smooth hover effects and instant feedback across the UI.

---

## 🚀 Blazing Fast Performance

- **Native C++ MTP Bridge**  
  No wrappers — One Share communicates directly with libmtp.

- **Native C++ AFC/HouseArrest Bridge**  
  Direct communication with iOS devices using libimobiledevice.

- **Recursive Folder Downloads**  
  Drag entire folders from devices to Mac in one go.

- **Smart Caching**  
  Navigating directories feels instant.

---

## 🔌 Seamless Connectivity

- **Auto-Detection**  
  Plug in your device — it appears instantly.

- **Smart Permission Handling**  
  If your phone is locked, One Share waits and refreshes automatically once unlocked.

- **Force Reconnect Button**  
  Fixes stubborn permission issues instantly.

---

## 📁 Project Structure

```
OneShare/
├── Lumen/ # Main SwiftUI macOS app
│ ├── App/ # App entry & lifecycle
│ ├── Views/ # All UI components & screens
│ ├── Models/ # Data models (Files, Directories)
│ ├── ViewModels/ # Logic & state management
│ ├── Services/ # MTP, AFC, device bridging, caching
│ └── Utils/ # Extensions & helpers
│
├── MTPBridge/ # C++ libmtp Wrapper
│ ├── include/
│ ├── src/
│ └── bridge.mm # Objective-C++ bridge to Swift
│
├── iOSBridge/ # C++ libimobiledevice Wrapper
│ ├── include/
│ ├── src/
│ └── ios_bridge.mm # Objective-C++ bridge to Swift
│
├── Resources/ # Assets, icons, UI materials
├── Lumen.xcodeproj # Xcode project file
└── README.md # Documentation
```

---

## 📥 Download & Install

You don't need to be a developer to use One Share. Just:

1. **Download the latest `.dmg`**  
   https://github.com/zakisheriff/OneShare/releases/latest

2. Open the `.dmg`.

3. Drag **One Share** into **Applications**.

4. Launch the app and plug in your Android or iOS device.

---

## 🛠️ For Developers

### 1. Clone the repository

git clone https://github.com/zakisheriff/OneShare.git

### 2. Install Dependencies

Requires `libmtp` and `libimobiledevice`:

brew install libmtp libimobiledevice

### 3. Build

Open in Xcode → **Run (⌘ + R)**.

---

## ☕️ Support the Project

If One Share helped you, inspired you, or saved you from outdated file transfer tools:

- Consider buying me a coffee
- It keeps development alive and motivates future updates

<div align="center">
<a href="https://buymeacoffee.com/zakisheriffw">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="60" width="217">
</a>
</div>

---

<p align="center">
Made with Swift by <strong>Zaki Sheriff</strong>
</p>
