# <div align="center">One Share</div>

<div align="center">
<strong>Dual-Protocol File Transfer for macOS & Android</strong>
<br />
<em>Wired + Wireless • Mac ↔ Android ↔ iOS</em>
</div>

<br />

<div align="center">

![macOS](https://img.shields.io/badge/macOS-15.0+-000000?style=for-the-badge&logo=apple&logoColor=white)
![Android](https://img.shields.io/badge/Android-12+-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)
![React Native](https://img.shields.io/badge/React_Native-Expo-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

<br />

[![Download Mac](https://img.shields.io/badge/Download_Mac-DMG-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/zakisheriff/OneShare/releases/latest)
[![Download Android](https://img.shields.io/badge/Download_Android-APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/zakisheriff/OneShare/releases/latest)

</div>

<br />

> **"It feels like it was built by Apple — and Google."**
>
> One Share bridges the gap between your devices with **two transfer modes**:
> - 🔌 **Wired**: USB transfers via MTP (Android) and AFC (iOS)
> - 📡 **Wireless**: Bluetooth discovery + WiFi Direct transfers

---

## ✨ Features at a Glance

| Feature | Mac App | Android App |
|---------|---------|-------------|
| 🔌 **USB Wired Transfer** | ✅ MTP + AFC | — |
| 📡 **Wireless Transfer** | ✅ BLE + TCP | ✅ BLE + TCP |
| 🎨 **Liquid Glass UI** | ✅ SwiftUI | ✅ React Native |
| 📂 **File Browser** | ✅ Full access | ✅ Send files |
| 🔐 **Secure Pairing** | ✅ 4-digit code | ✅ 4-digit code |
| ⚡ **Fast Streaming** | ✅ 128KB chunks | ✅ 128KB chunks |

---

## 🔌 Wired Transfer (USB)

The Mac app provides a **native file explorer** for connected devices:

- **Android via MTP**: Browse, copy, paste, delete files directly
- **iOS via AFC**: Access app documents and media
- **Auto-Detection**: Devices appear instantly when plugged in
- **Recursive Downloads**: Drag entire folders to your Mac
- **Smart Caching**: Directory navigation feels instant

---

## 📡 Wireless Transfer (Bluetooth + WiFi)

Transfer files **without cables** between Mac and Android:

### How It Works
1. **Discovery**: Devices find each other via Bluetooth Low Energy (BLE)
2. **Pairing**: Secure 4-digit code verification
3. **Transfer**: High-speed TCP over WiFi (same network or hotspot)

### Wireless Features
- **No Internet Required**: Works over local WiFi or hotspot
- **Auto-Accept**: Paired devices transfer instantly
- **Real-Time Progress**: Speed, ETA, and percentage
- **Drag & Drop**: Drop files onto the session view to send
- **Transfer History**: See all sent and received files

---

## 🎨 Liquid Glass UI

Both apps feature a premium, modern aesthetic:

### Mac (SwiftUI)
- Native macOS materials (`.ultraThinMaterial`)
- Frosted glass device cards and panels
- Smooth animations and hover effects
- Dark mode optimized

### Android (React Native)
- Glass container components with blur
- Dark theme with subtle gradients
- Platform-native haptic feedback
- Bottom tab navigation

---

## 📥 Installation

### Mac App

1. **Download** `OneShare.dmg` from [Releases](https://github.com/zakisheriff/OneShare/releases/latest)
2. Open the `.dmg`
3. Drag **One Share** to **Applications**
4. Launch and connect your device

### Android App

1. **Download** `OneShare.apk` from [Releases](https://github.com/zakisheriff/OneShare/releases/latest)
2. Enable "Install from Unknown Sources" if prompted
3. Install and launch
4. Grant Bluetooth and Location permissions (required for BLE)

---

## �️ For Developers

### Prerequisites

**Mac App:**
```bash
brew install libmtp libimobiledevice
```

**Android App:**
```bash
cd oneshare-android
npm install
```

### Building

**Mac:**
```bash
open Lumen.xcodeproj
# Run (⌘ + R)
```

**Android:**
```bash
cd oneshare-android
npx expo run:android
```

---

## 📁 Project Structure

```
OneShare/
├── Lumen/                   # macOS SwiftUI App
│   ├── WirelessTransfer/    # Bluetooth + TCP networking
│   │   ├── NetworkManager   # TCP server/client
│   │   ├── DiscoveryManager # BLE scanning/advertising
│   │   ├── PairingManager   # Secure code verification
│   │   └── SessionView      # Trusted session UI
│   ├── MTPBridge/           # C++ libmtp wrapper
│   ├── iOSBridge/           # C++ libimobiledevice wrapper
│   └── Views/               # SwiftUI components
│
├── oneshare-android/        # Android React Native App
│   ├── src/
│   │   ├── screens/         # HomeScreen, RecentsScreen
│   │   ├── components/      # TransferModal, PairingModal
│   │   └── services/        # TransferService, BleService
│   └── android/
│       └── modules/         # Native Kotlin networking
│
└── README.md
```

---

## 🔒 Privacy & Security

- **Local Only**: All transfers happen on your local network
- **No Cloud**: Your files never leave your devices
- **Secure Pairing**: 4-digit code prevents unauthorized access
- **Open Source**: Full transparency of code

---

## ☕️ Support the Project

If One Share helped you, consider supporting development:

<div align="center">
<a href="https://buymeacoffee.com/zakisheriffw">
<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="60" width="217">
</a>
</div>

---

<p align="center">
Made by <strong>Zaki Sheriff</strong>
<br />
Swift • Kotlin • React Native
</p>
