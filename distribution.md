# 🚢 Dispatch: Distribution Guide

This guide walks you through every step to take your local code to a professional GitHub release and Homebrew installation.

## 🔒 1. Secret Management
Before you do anything, ensure your OAuth App credentials are safe.
- **`Secrets.swift`**: This file is already in your `.gitignore`. It contains your `clientID`.
- **`Secrets.swift.example`**: This is pushed to GitHub as a template for other developers.
- **Action**: Verify that `Config.swift` reads from `Secrets.githubClientID`.

---

## 🛠 2. Xcode Professional Prep
### A. Signing & Capabilities
1. Open `Dispatch.xcodeproj` in Xcode.
2. Select the **Dispatch** target.
3. Go to **Signing & Capabilities**.
4. Select your **Development Team** (Apple Developer Account).
5. Ensure "Automatically manage signing" is checked if you want Xcode to handle the certificates.

### B. Archive & Notarization
1. Select **Product > Archive**.
2. Once finished, the Organizer window appears.
3. Click **Distribute App**.
4. Choose **Developer ID** (This is for distributing outside the App Store).
5. Choose **Upload** (to send to Apple's Notary service).
6. Wait for the green "Ready to distribute" status (usually takes 2-5 minutes).
7. Click **Export** and save the `Dispatch.app` to your Desktop.

---

## 🐙 3. Git & GitHub Setup
### A. Initialize Repository
If you haven't pushed yet:
1. Open Terminal in the root directory.
2. `git init`
3. `git add .` (Verify that `Secrets.swift` and build folders are ignored).
4. `git commit -m "Initial release of Dispatch"`
5. `git remote add origin https://github.com/YOUR_USERNAME/dispatch.git`
6. `git push -u origin main`

### B. Create a GitHub Release
1. Go to your repo on GitHub.
2. Click **Releases > Create a new release**.
3. Tag it `v1.0.0`.
4. **Upload Artifact**: Compress your `Dispatch.app` into `Dispatch.zip` and drag it into the release assets.
5. Publish.

---

## 🍺 4. Homebrew Cask Distribution
To let users install with `brew install --cask dispatch`:
1. Create a repo called `homebrew-tap` (e.g., `github.com/YOUR_USERNAME/homebrew-tap`).
2. Inside, create a folder `Casks`.
3. Create `Casks/dispatch.rb`.
4. Get the **SHA256** of your zip: `shasum -a 256 ~/Desktop/Dispatch.zip`.
5. Paste the following into `dispatch.rb`:

```ruby
cask "dispatch" do
  version "1.0.0"
  sha256 "PASTE_YOUR_SHA256_HERE"

  url "https://github.com/YOUR_USERNAME/dispatch/releases/download/v#{version}/Dispatch.zip"
  name "Dispatch"
  desc "Native macOS GitHub PR Event Monitor"
  homepage "https://github.com/YOUR_USERNAME/dispatch"

  app "Dispatch.app"
end
```

---

## ✅ 5. Final Checklist
- [ ] `Secrets.swift` is in `.gitignore`.
- [ ] App is Notarized (no "Unknown Developer" warnings).
- [ ] Homebrew tap points to the correct ZIP URL.
