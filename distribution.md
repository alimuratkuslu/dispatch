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
  sha256 "7e8b8020d0f5efc0f0c0839cb3283a0370b0a37cf3b86958f65b684928cd5945"

  url "https://github.com/alimuratkuslu/dispatch/releases/download/v#{version}/Dispatch.zip"
  name "Dispatch"
  desc "Native macOS GitHub PR Event Monitor"
  homepage "https://github.com/alimuratkuslu/dispatch"

  app "Dispatch.app"
end
```

---

### B. Fully Automated Sync (Recommended)
You can now automate the entire process so that `brew upgrade` works instantly after a release.
1. **Create a PAT**: Go to [GitHub Developer Settings](https://github.com/settings/tokens/new) and create a "Personal Access Token (classic)".
   - Select the **`repo`** scope.
   - Copy the token.
2. **Add to Secrets**: Go to your **`dispatch`** repository → **Settings** → **Secrets and variables** → **Actions**.
   - Click **New repository secret**.
   - Name: **`HOMEBREW_TAP_TOKEN`**.
   - Value: Paste your PAT.
3. **That's it!**: Every time you push a tag like `v1.2.2`, the CI will automatically:
   - Build and release the app.
   - Calculate the new SHA256.
   - Clone your `homebrew-tap` repo and update `Casks/dispatch.rb`.
   - Push the update so users can run `brew upgrade`.

## ✅ 5. Final Checklist
- [ ] `Secrets.swift` is in `.gitignore`.
- [ ] App is Notarized (no "Unknown Developer" warnings).
- [ ] Homebrew tap points to the correct ZIP URL.

---

## 🚀 6. Automated Releases (GitHub Actions)
We have implemented a GitHub Actions workflow to automate the build and release process.

### How to Release:
1. **Commit your changes**: Ensure everything is pushed to `main`.
2. **Create a Tag**: 
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
3. **Wait for CI**: GitHub Actions will automatically:
   - Build the app in Release mode.
   - Archive it into a `.zip`.
   - Create a new GitHub Release with the version number.
   - Attach the `Dispatch.zip` as a release asset.

> [!IMPORTANT]
> **Prerequisite for CI**: You MUST go to your GitHub repo settings → **Secrets and variables** → **Actions** and add a secret named `GITHUB_CLIENT_ID` containing your OAuth App client ID. The release workflow needs this to generate `Secrets.swift` during the build.

## 📥 7. Installation & Updates

### **First Time Installation**
1. Go to the [Releases](https://github.com/alimuratkuslu/dispatch/releases) page of your repository.
2. Download the `Dispatch.zip` file from the latest release.
3. Double-click the ZIP to extract it.
4. Drag `Dispatch.app` into your **Applications** folder.
5. Right-click `Dispatch.app` and choose **Open** (the first time only) to bypass any "Unidentified Developer" warnings if you haven't notarized it yet.

### **Updating to a New Version**
1. Follow the same steps as above to download the latest `Dispatch.zip`.
2. Drag the new `Dispatch.app` into your **Applications** folder, choosing **Replace** when prompted.
3. Your account tokens and monitored repositories are stored securely in the system Keychain and UserDefaults, so they will persist across updates.

### **Troubleshooting Notifications**
If you are not receiving alerts after installing:
1. Open **Dispatch Preferences** (Right-click menu icon -> Preferences).
2. Go to the **Notifications** tab.
3. Check the **Permission** status:
   - If it says **"Not Granted"**, click the button to request permission or go to macOS System Settings -> Notifications -> Dispatch to enable them manually.
4. Click **"Send Test Notification"** to verify the connection.
5. **CI Signing**: Ensure you are using the app built by GitHub Actions (v1.2.2+). These versions are ad-hoc signed, which is required for reliable notification delivery on macOS 15+.
