# <div align="center">Lumen</div>
<div align="center">
<strong>The Next-Generation Android File Transfer for macOS</strong>
</div>

<br />

<div align="center">

<img src="assets/badges/macos-tahoe.svg" height="50" />
<img src="assets/badges/swift.svg" height="50" />
<img src="assets/badges/license.svg" height="50" />

<br />

<a href="https://github.com/zakisheriff/Lumen/releases/latest">
<img src="assets/badges/download-dmg.svg" height="50" />
</a>

</div>


<br />

> **"It feels like it was built by Apple."**
>
> Lumen isn't just a tool; it's a seamless extension of your Mac.  
> Designed with the fluid, glassy aesthetics of **macOS 26**, it bridges the gap between your Android device and your Mac with elegance and speed.

---

## 🌟 Vision

Lumen’s purpose is to be:

- **A next-generation macOS file explorer** for Android  
- **A beautifully native SwiftUI application** showcasing true Apple-level design  
- **A fast, stable, modern alternative** to outdated Android File Transfer tools  

---

## ✨ Why Lumen?

Forget the clunky, outdated file transfer tools of the past.  
Lumen is built from the ground up to be **fast, beautiful, and truly native**.

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
  No wrappers — Lumen communicates directly with libmtp.

- **Recursive Folder Downloads**  
  Drag entire folders from Android to Mac in one go.

- **Smart Caching**  
  Navigating directories feels instant.

---

## 🔌 Seamless Connectivity

- **Auto-Detection**  
  Plug in your device — it appears instantly.

- **Smart Permission Handling**  
  If your phone is locked, Lumen waits and refreshes automatically once unlocked.

- **Force Reconnect Button**  
  Fixes stubborn permission issues instantly.

---

## 📁 Project Structure

```
Lumen/
├── Lumen/ # Main SwiftUI macOS app
│ ├── App/ # App entry & lifecycle
│ ├── Views/ # All UI components & screens
│ ├── Models/ # Data models (Files, Directories)
│ ├── ViewModels/ # Logic & state management
│ ├── Services/ # MTP, device bridging, caching
│ └── Utils/ # Extensions & helpers
│
├── MTPBridge/ # C++ libmtp Wrapper
│ ├── include/
│ ├── src/
│ └── bridge.mm # Objective-C++ bridge to Swift
│
├── Resources/ # Assets, icons, UI materials
├── Lumen.xcodeproj # Xcode project file
└── README.md # Documentation
```

---

## 📥 Download & Install

You don’t need to be a developer to use Lumen. Just:

1. **Download the latest `.dmg`**  
   https://github.com/zakisheriff/Lumen/releases/latest

2. Open the `.dmg`.

3. Drag **Lumen** into **Applications**.

4. Launch the app and plug in your Android phone.

---

## 🛠️ For Developers

### 1. Clone the repository

git clone https://github.com/zakisheriff/Lumen.git

### 2. Install Dependencies

Requires `libmtp`:

brew install libmtp

### 3. Build

Open in Xcode → **Run (⌘ + R)**.

---

## ☕️ Support the Project

If Lumen helped you, inspired you, or saved you from Android File Transfer hell:

- Consider buying me a coffee  
- It keeps development alive and motivates future updates

<div align="center">
<a href="https://buymeacoffee.com/zakisherifw">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="60" width="217">
</a>
</div>

---

<p align="center">
Made with Swift by <strong>Zaki Sheriff</strong>
</p>
