# Lumen ⚡️
### The Next-Generation Android File Transfer for macOS

![Lumen Banner](https://img.shields.io/badge/Lumen-macOS_26_Ready-blue?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey?style=flat-square&logo=apple)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

> **Experience the future of file transfer.** Lumen isn't just a tool; it's a seamless extension of your Mac, designed with the fluid, glassy aesthetics of **macOS 26**.

---

## ✨ Why Lumen?

Forget the clunky, outdated file transfer tools of the past. Lumen is built from the ground up to be **fast, beautiful, and native**.

### 🎨 Stunning "Liquid Glass" UI
-   **Native Aesthetics**: Built with SwiftUI and designed to feel right at home on the latest macOS.
-   **Unified Window**: A seamless, translucent sidebar that merges perfectly with the title bar.
-   **Liquid Selection**: Files and folders highlight with a premium, rounded, and subtle glassy effect.
-   **Zero-Latency Interaction**: Instant selection and smooth hover effects that feel alive.

### 🚀 Blazing Fast Performance
-   **Native C++ MTP Bridge**: We don't rely on slow wrappers. Lumen talks directly to `libmtp` for maximum speed.
-   **Recursive Folder Download**: Drag entire folders from your Android device to your Mac instantly.
-   **Smart Caching**: Browsing directories is snappy and responsive.

### 🔌 Seamless Connectivity
-   **Auto-Detection**: Plug in your phone, and Lumen sees it instantly.
-   **Smart Permission Handling**: Forgot to unlock your phone? Lumen politely asks and auto-refreshes the moment you grant access. No restarts needed.
-   **Force Reconnect**: A dedicated "I've Allowed Access" button for when you need that extra push.

---

## 🛠️ Technical Highlights

Lumen is a showcase of modern macOS development:

-   **Swift Concurrency**: Powered by `async/await` for a UI that never freezes.
-   **Interoperability**: A robust C++ bridge connecting Swift to the low-level `libmtp` library.
-   **System Integration**:
    -   **NSFilePromiseProvider**: Native drag-and-drop support that plays nicely with Finder.
    -   **Unified Toolbar**: A modern window style that maximizes screen real estate.

---

## 📦 Installation

1.  **Clone the repo**:
    ```bash
    git clone https://github.com/yourusername/Lumen.git
    ```
2.  **Install Dependencies**:
    Ensure you have `libmtp` installed via Homebrew:
    ```bash
    brew install libmtp
    ```
3.  **Build**:
    Open `Lumen.xcodeproj` in Xcode and hit **Run** (Cmd+R).

---

## 🤝 Contributing

We believe in open source. Want to make Lumen even better?
1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

## ☕️ Support

If Lumen saved you time (or just looks too good to resist), consider buying me a coffee!

<a href="https://buymeacoffee.com/zakisherifw">
  <img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=zakisherifw&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" />
</a>

---

<p align="center">
  Made with ❤️ and Swift by Zaki Sheriff
</p>
