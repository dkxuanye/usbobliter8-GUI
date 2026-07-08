# usbobliter8

Erasing tool for A12/A13 iOS devices. Uploads a patched iBEC, and triggers iOS' built-in obliteration (erase all).

## Usage (Python version)

1. Enter PWND DFU mode with [usbliter8](https://github.com/prdgmshift/usbliter8)
2. Run `usbobliter8` and click `Obliter8!`
3. Device reboots and begins erasing

## Requirements (Python version)

- macOS 10.13+, Windows, or Linux
- libusb:
  - **macOS**: `brew install libusb`
  - **Linux**: `apt install libusb-1.0-0-dev`
  - **Windows**: Install [Zadig](https://zadig.akeo.ie/) and replace the Apple DFU driver with `libusbK`

---

# EraseA12 (Native macOS App)

A native macOS version of usbobliter8, built with Swift + AppKit. No Python runtime is required.

### Features
- Detects PWND DFU devices automatically via USB
- Guided 4-step wizard: Connect → Confirm → Erase → Done
- Modern Liquid Glass UI with macOS version adaptation
- Supports all 11 A12/A13 devices from usbobliter8
- Simplified Chinese interface throughout the app

### Requirements
- macOS 10.15 (Catalina) or later
- A12/A13 iOS device in PWND DFU mode (use [usbliter8](https://github.com/prdgmshift/usbliter8) first)

### Building from Source

1. Install dependencies:
   ```bash
   brew install xcodegen
   ```

2. Build vendor libraries (one-time):
   ```bash
   cd EraseA12
   ./Scripts/build-vendor-libs.sh
   ```

3. Build the app:
   ```bash
   make build
   ```

4. Run tests:
   ```bash
   make test
   ```

5. Package DMG:
   ```bash
   ./Scripts/package-dmg.sh
   ```
   The script generates a Finder-friendly DMG with:
   - Custom dark background image (auto-applied via `.DS_Store`) showing drag-to-Applications instructions
   - `Applications` shortcut linking to your local `/Applications`
   - Chinese + English `打开方式.txt` with Gatekeeper instructions

   Optional: skip Finder window layout (for CI) with `SKIP_DMG_FINDER_LAYOUT=1`.

### First Launch

Since EraseA12 is not code-signed with a paid developer certificate:
1. Right-click the app → Select "Open"
2. Or go to **System Settings → Privacy & Security** and click "Open Anyway"

### Current Packaging Limitation

The current local Release build still dynamically links Homebrew OpenSSL from
`/usr/local/opt/openssl@3`. Bundle or statically link OpenSSL before distributing the
app to Macs that do not provide those libraries at the same path.
