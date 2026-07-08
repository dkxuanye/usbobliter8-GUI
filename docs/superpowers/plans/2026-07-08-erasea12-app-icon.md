# EraseA12 App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and ship a dedicated macOS AppIcon that depicts a device being wiped by a blue scan band and replaces the generic application icon.

**Architecture:** Keep the icon entirely in the existing asset catalog and declare `AppIcon` in the xcodegen source configuration. Add a source-tree XCTest contract that validates every macOS icon slot, filename, and pixel dimension so the ignored generated Xcode project cannot hide missing assets. Generate one 1024×1024 master, remove its flat chroma-key exterior, and derive every smaller PNG from that master.

**Tech Stack:** Swift 5, XCTest, AppKit image decoding, Xcode asset catalogs, xcodegen YAML, built-in image generation, `remove_chroma_key.py`, `sips`, Xcode 14.3 command-line tools.

## Global Constraints

- Keep the deployment target at macOS 10.15 and add no third-party dependency.
- Use a deep graphite rounded-square tile, silver device outline, electric-blue horizontal wipe band, and one restrained warm-red warning point.
- Include no text, Apple logo, trademark, realistic iPhone details, trash can, skull, explosion, circular-arrow primary symbol, watermark, or mockup scene.
- Preserve the existing erase workflow, USB detection, menus, windows, fixed Simplified Chinese UI, copyright information, and About-window behavior.
- Treat `EraseA12/project.yml` as the project source of truth; do not commit the ignored `EraseA12.xcodeproj`.
- Do not commit temporary generation files, previews, screenshots, logs, `EraseA12.app/`, or `build/`.
- Do not connect to or erase a real device.

---

### Task 1: Add and satisfy an executable AppIcon asset contract

**Files:**
- Modify: `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png`
- Create: `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`
- Modify: `EraseA12/project.yml`
- Test: `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift`

**Interfaces:**
- Consumes: the source-tree layout rooted at `EraseA12/`, plus macOS asset-catalog `Contents.json` entries containing `idiom`, `size`, `scale`, and `filename`.
- Produces: `testAppIconCatalogContainsEveryMacSlotAtTheCorrectPixelSize()` plus the complete `AppIcon.appiconset` selected by `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.

- [ ] **Step 1: Write the failing source-tree XCTest**

Add this test inside `StepIndicatorViewTests`:

```swift
func testAppIconCatalogContainsEveryMacSlotAtTheCorrectPixelSize() throws {
    let eraseA12Root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let appIconDirectory = eraseA12Root
        .appendingPathComponent("EraseA12/Resources/Assets.xcassets/AppIcon.appiconset")
    let contentsURL = appIconDirectory.appendingPathComponent("Contents.json")
    let contentsData = try Data(contentsOf: contentsURL)
    let root = try XCTUnwrap(
        JSONSerialization.jsonObject(with: contentsData) as? [String: Any]
    )
    let images = try XCTUnwrap(root["images"] as? [[String: String]])
    let expectedSlots: Set<String> = [
        "16x16-1x", "16x16-2x",
        "32x32-1x", "32x32-2x",
        "128x128-1x", "128x128-2x",
        "256x256-1x", "256x256-2x",
        "512x512-1x", "512x512-2x"
    ]
    let actualSlots = Set(images.compactMap { image -> String? in
        guard let size = image["size"], let scale = image["scale"] else { return nil }
        return "\(size)-\(scale)"
    })

    XCTAssertEqual(images.count, 10)
    XCTAssertEqual(actualSlots, expectedSlots)

    for image in images {
        let filename = try XCTUnwrap(image["filename"])
        let size = try XCTUnwrap(image["size"])
        let scale = try XCTUnwrap(image["scale"])
        XCTAssertEqual(image["idiom"], "mac")

        let basePixels = try XCTUnwrap(Int(size.split(separator: "x")[0]))
        let scaleMultiplier = try XCTUnwrap(Int(scale.dropLast()))
        let expectedPixels = basePixels * scaleMultiplier
        let data = try Data(contentsOf: appIconDirectory.appendingPathComponent(filename))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))

        XCTAssertEqual(bitmap.pixelsWide, expectedPixels, filename)
        XCTAssertEqual(bitmap.pixelsHigh, expectedPixels, filename)
    }

    let projectYAML = try String(
        contentsOf: eraseA12Root.appendingPathComponent("project.yml"),
        encoding: .utf8
    )
    XCTAssertTrue(projectYAML.contains("ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon"))
}
```

- [ ] **Step 2: Run the focused test and verify the RED state**

Run:

```bash
xcodebuild test \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:EraseA12Tests/StepIndicatorViewTests/testAppIconCatalogContainsEveryMacSlotAtTheCorrectPixelSize
```

Expected: the test fails because
`Assets.xcassets/AppIcon.appiconset/Contents.json` does not exist.

- [ ] **Step 3: Generate one 1024×1024 master on a removable chroma-key exterior**

Use the built-in image generator with this exact prompt and no reference image:

```text
Use case: logo-brand
Asset type: macOS application icon master
Primary request: an original application icon for EraseA12, showing a simplified mobile device being permanently wiped clean by one horizontal electric-blue scanning band moving from left to right
Scene/backdrop: the icon itself sits alone on a perfectly flat solid #ff00ff chroma-key exterior with no floor, shadow, gradient, texture, or reflection outside the icon tile
Subject: a deep graphite rounded-square icon tile; centered silver-white generic mobile-device outline occupying about 56 percent of the tile; the electric-blue band crosses the middle and leaves a visibly clean dark region behind it; one very small warm-red status point indicates an irreversible action
Style/medium: polished vector-like macOS utility icon; minimal; strong silhouette; restrained material depth; crisp edges; professional rather than playful
Composition/framing: single centered icon, front-facing, symmetric visual balance, generous safe margin, readable at 16×16 pixels
Color palette: graphite black, silver white, electric blue, one tiny warm-red accent; do not use #ff00ff inside the icon subject
Constraints: exactly one icon only; no text; no letters; no numbers; no Apple logo; no trademarks; no realistic iPhone details; no USB plug; no chip; no trash can; no skull; no explosion; no lightning bolt; no circular arrow; no mockup; no decorative background objects; no watermark
Avoid: excessive glow, tiny details, busy gradients, photo realism, notification-badge appearance, error-screen appearance
```

Save the generated source outside the repository as `/tmp/erasea12-app-icon-source.png`.

- [ ] **Step 4: Remove only the chroma-key exterior and inspect the master**

Run:

```bash
python /Users/dkxuanye/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py \
  --input /tmp/erasea12-app-icon-source.png \
  --out /tmp/erasea12-app-icon-master.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill

sips -g pixelWidth -g pixelHeight -g hasAlpha /tmp/erasea12-app-icon-master.png
```

Expected: width 1024, height 1024, and `hasAlpha: yes`. Inspect the image at original size and a 16×16 preview; reject and regenerate if the phone, wipe direction, or silhouette is ambiguous.

- [ ] **Step 5: Create the asset catalog metadata**

Create `AppIcon.appiconset/Contents.json` with:

```json
{
  "images" : [
    { "filename" : "AppIcon-16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "AppIcon-16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "AppIcon-32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "AppIcon-32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "AppIcon-128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "AppIcon-128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "AppIcon-256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "AppIcon-256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "AppIcon-512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "AppIcon-512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 6: Derive every PNG from the accepted master**

Run:

```bash
mkdir -p EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset
cp /tmp/erasea12-app-icon-master.png EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png
sips -z 512 512 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png
sips -z 512 512 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256@2x.png
sips -z 256 256 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png
sips -z 256 256 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png
sips -z 128 128 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png
sips -z 64 64 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-32@2x.png
sips -z 32 32 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png
sips -z 32 32 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-16@2x.png
sips -z 16 16 /tmp/erasea12-app-icon-master.png --out EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png
```

- [ ] **Step 7: Declare the AppIcon name in the xcodegen source**

Add this setting under `targets.EraseA12.settings.base` in `EraseA12/project.yml`:

```yaml
ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

The ignored generated Xcode project already contains the matching build setting, so do not hand-edit or commit it.

- [ ] **Step 8: Run the focused test and verify the GREEN state**

Run the focused `xcodebuild test` command from Task 1 again.

Expected: `testAppIconCatalogContainsEveryMacSlotAtTheCorrectPixelSize` passes.

- [ ] **Step 9: Commit the tested icon assets**

```bash
git add \
  EraseA12/EraseA12Tests/StepIndicatorViewTests.swift \
  EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset \
  EraseA12/project.yml
git diff --cached --check
git commit -m "feat: add EraseA12 app icon"
```

---

### Task 2: Verify the Release bundle and update project continuity

**Files:**
- Modify: `HANDOFF.md`
- Modify: `DEV_LOG.md`
- Modify: `TODO.md`
- Modify: `docs/superpowers/specs/2026-07-08-erasea12-app-icon-design.md`

**Interfaces:**
- Consumes: the complete asset catalog and project setting from Task 1.
- Produces: a freshly built local `EraseA12.app`, current project handoff records, and a final verification report; generated application and screenshots remain untracked.

- [ ] **Step 1: Run the complete test suite**

```bash
xcodebuild test \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Debug \
  -destination 'platform=macOS'
```

Expected: all prior 32 tests plus the new AppIcon contract pass with 0 failures.

- [ ] **Step 2: Perform a clean Release build to the repository root**

```bash
rm -rf /tmp/EraseA12IconDerivedData
xcodebuild clean build \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Release \
  -derivedDataPath /tmp/EraseA12IconDerivedData \
  CONFIGURATION_BUILD_DIR="$PWD"
```

Expected: `** BUILD SUCCEEDED **` and a freshly created local `EraseA12.app`.

- [ ] **Step 3: Verify bundle metadata, compiled icon, signing, architecture, dependencies, resources, and strings**

```bash
plutil -p EraseA12.app/Contents/Info.plist | grep -E 'CFBundleIcon|CFBundleName'
test -f EraseA12.app/Contents/Resources/Assets.car
codesign --verify --deep --strict --verbose=2 EraseA12.app
file EraseA12.app/Contents/MacOS/EraseA12
otool -L EraseA12.app/Contents/MacOS/EraseA12
find EraseA12.app/Contents/Resources -name 'iBEC.*.RELEASE.patched' | wc -l
plutil -lint EraseA12/EraseA12/Resources/*/Localizable.strings
git diff --check
```

Expected: icon metadata is present, `Assets.car` exists, strict signing passes, the executable contains `x86_64` and `arm64`, 11 iBEC files are present, and both string tables pass. Record the known Homebrew OpenSSL dynamic dependencies as an unchanged limitation.

- [ ] **Step 4: Launch and visually inspect the built app without a device**

Open the Release app and confirm the new icon appears in the Dock and in the About window. Inspect 16×16, 32×32, 128×128, and 512×512 source PNGs; the device and horizontal wipe must remain legible and the red point must stay subordinate. Do not connect a device or enter the erase workflow.

- [ ] **Step 5: Update the required project records**

Update `HANDOFF.md`, prepend a dated AppIcon entry to `DEV_LOG.md`, mark the custom app icon complete in `TODO.md`, and change the icon design specification status from `待实施` to `已实施并验证`. Include the exact test count, build/signing result, icon bundle evidence, executable SHA-256, and the unchanged OpenSSL limitation.

- [ ] **Step 6: Commit the verified documentation**

```bash
git add \
  HANDOFF.md \
  DEV_LOG.md \
  TODO.md \
  docs/superpowers/specs/2026-07-08-erasea12-app-icon-design.md
git diff --cached --check
git commit -m "docs: record app icon verification"
git status --short --branch
```

Expected: the source worktree is clean apart from ignored local build products, and `main` contains the icon implementation and verification commits.
