<p align="center">
  <img src="https://raw.githubusercontent.com/alimuratkuslu/dispatch/main/Dispatch/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" />
</p>

<h1 align="center">Dispatch</h1>

<p align="center">
  <strong>Native macOS GitHub Pull Request Monitor</strong><br />
  Stay on top of reviews, comments, and CI/CD without leaving your menu bar.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-FFB400?style=for-the-badge&logo=apple" />
  <img src="https://img.shields.io/badge/Swift-5.10-FA7343?style=for-the-badge&logo=swift" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" />
</p>

---

## ✨ Features

- 🚀 **Real-Time Monitoring**: Adaptive menu bar icon with CI health and review status dots.
- 💎 **Elite UI**: Glassmorphism design, micro-animations, and native popover anchoring.
- 💬 **In-App Collaboration**: Reply to review threads directly without leaving the app.
- ⚠️ **Conflict Detection**: Visual warnings and "Copy Fix Command" for merge conflicts.
- 🤖 **AI-Ready**: Trigger Copilot reviews and view AI-generated PR summaries.
- 🔒 **Secure**: OAuth login with tokens stored safely in your macOS Keychain.
- 🆓 **100% Free**: No paywalls, no limits, just pure open-source productivity.

## 🚀 Installation

### Using Homebrew (Recommended)

```bash
brew tap alimuratkuslu/tap
brew install --cask dispatch
```

### Manual Download

1. Go to the [Releases](https://github.com/alimuratkuslu/dispatch/releases) page.
2. Download the `Dispatch.zip` file.
3. Move `Dispatch.app` to your `/Applications` folder.

## 🛠 Setup for Developers

1. Clone the repository: `git clone https://github.com/alimuratkuslu/dispatch.git`
2. Configure Secrets: 
   - y `Dispatch/App/Secrets.swift.example` to `Dispatch/App/Secrets.swift`.
   - Enter your [GitHub OAuth Client ID](https://github.com/settings/developers).
3. Open `Dispatch.xcodeproj` in Xcode.
4. Build & Run!

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or pull requests to improve the app.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<p align="center">
  Made with ❤️ for developers who love clean workflows.
</p>
