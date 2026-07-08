# EraseA12 Visible About Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-visible circular `!` button at the main window's top-right corner that opens the existing copyright About window.

**Architecture:** `MainWindowController` owns and lays out the button, then emits an `onShowAbout` callback when clicked. `AppDelegate` injects the callback and continues to own the existing `AboutWindowController`, so the main window remains independent of application lifecycle objects.

**Tech Stack:** Swift 5, AppKit, XCTest, Xcode 14.3, macOS 10.15+

## Global Constraints

- Preserve the existing `EraseA12 → 关于 EraseA12` menu entry.
- Display a circular text `!` button instead of requiring SF Symbols.
- Keep the button about 16 points from the top and right edges and clear of the centered step indicator.
- Set the accessibility label and tooltip to `关于 EraseA12`.
- Clicking the button must not change wizard state or invoke `ObliterationEngine`.
- Keep the deployment target at macOS 10.15 and add no third-party dependency.
- Do not connect to a device or run a destructive erase test.

---

### Task 1: Visible main-window About button

**Files:**
- Modify: `EraseA12/EraseA12/UI/MainWindowController.swift`
- Modify: `EraseA12/EraseA12/App/AppDelegate.swift`
- Modify: `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift`

**Interfaces:**
- Produces: `MainWindowController.onShowAbout: (() -> Void)?`.
- Consumes: `AppDelegate.showAboutWindow(_:)`, which already owns and displays the About window.

- [ ] **Step 1: Write failing visibility, placement, and click tests**

Add these tests to `StepIndicatorViewTests`:

```swift
func testMainWindowShowsAboutButtonInTopRightCorner() {
    let controller = MainWindowController()
    let contentView = controller.window!.contentView!
    contentView.layoutSubtreeIfNeeded()

    let aboutButton = Self.buttons(in: contentView).first { $0.title == "!" }
    let stepIndicator = Self.firstSubview(of: StepIndicatorView.self, in: contentView)

    XCTAssertNotNil(aboutButton)
    XCTAssertEqual(aboutButton?.accessibilityLabel(), "关于 EraseA12")
    XCTAssertEqual(aboutButton?.toolTip, "关于 EraseA12")
    XCTAssertLessThanOrEqual(contentView.bounds.maxX - aboutButton!.frame.maxX, 16)
    XCTAssertLessThanOrEqual(contentView.bounds.maxY - aboutButton!.frame.maxY, 16)
    XCTAssertFalse(aboutButton!.frame.intersects(stepIndicator!.frame))
}

func testMainWindowAboutButtonCallsCallbackOnce() {
    let controller = MainWindowController()
    var callCount = 0
    controller.onShowAbout = { callCount += 1 }

    let contentView = controller.window!.contentView!
    let aboutButton = Self.buttons(in: contentView).first { $0.title == "!" }
    aboutButton?.performClick(nil)

    XCTAssertEqual(callCount, 1)
}
```

Add recursive test helpers:

```swift
private static func buttons(in view: NSView) -> [NSButton] {
    let own = (view as? NSButton).map { [$0] } ?? []
    return own + view.subviews.flatMap { buttons(in: $0) }
}

private static func firstSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
    if let match = view as? T { return match }
    return view.subviews.lazy.compactMap { firstSubview(of: type, in: $0) }.first
}
```

- [ ] **Step 2: Run the focused tests and verify red**

```bash
xcodebuild test \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:EraseA12Tests/StepIndicatorViewTests
```

Expected: compilation fails because `MainWindowController` has no `onShowAbout` property.

- [ ] **Step 3: Implement the button and callback**

Add to `MainWindowController`:

```swift
var onShowAbout: (() -> Void)?
private let aboutButton = NSButton()
```

Inside `setupUI()`, configure and add the button before activating constraints:

```swift
let aboutTitle = L10n.text("about.menu_title", fallback: "关于 EraseA12")
aboutButton.title = "!"
aboutButton.bezelStyle = .circular
aboutButton.font = .systemFont(ofSize: 15, weight: .semibold)
aboutButton.contentTintColor = .secondaryLabelColor
aboutButton.toolTip = aboutTitle
aboutButton.setAccessibilityLabel(aboutTitle)
aboutButton.target = self
aboutButton.action = #selector(showAbout)
aboutButton.translatesAutoresizingMaskIntoConstraints = false
contentView.addSubview(aboutButton)
```

Add these constraints to the existing `NSLayoutConstraint.activate` array:

```swift
aboutButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
aboutButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
aboutButton.widthAnchor.constraint(equalToConstant: 28),
aboutButton.heightAnchor.constraint(equalToConstant: 28),
```

Add the action:

```swift
@objc private func showAbout(_ sender: Any?) {
    onShowAbout?()
}
```

After constructing the main window in `AppDelegate.applicationDidFinishLaunching`, inject:

```swift
controller.onShowAbout = { [weak self] in
    self?.showAboutWindow(nil)
}
```

- [ ] **Step 4: Run focused tests and verify green**

Run the focused test command from Step 2.

Expected: all `StepIndicatorViewTests` pass, including the two new button tests.

- [ ] **Step 5: Commit the tested UI change**

```bash
git add EraseA12/EraseA12/UI/MainWindowController.swift \
  EraseA12/EraseA12/App/AppDelegate.swift \
  EraseA12/EraseA12Tests/StepIndicatorViewTests.swift
git commit -m "fix: add visible About button"
```

### Task 2: Full verification, Release app, and handoff

**Files:**
- Modify: `HANDOFF.md`
- Modify: `DEV_LOG.md`
- Modify: `TODO.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/superpowers/specs/2026-07-08-erasea12-about-design.md`
- Modify: `docs/superpowers/plans/2026-07-08-erasea12-about-button.md`

**Interfaces:**
- Consumes: the tested visible About button from Task 1.
- Produces: a verified root-level `EraseA12.app` and durable project records.

- [ ] **Step 1: Run the complete XCTest suite**

```bash
xcodebuild test \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Debug \
  -destination 'platform=macOS'
```

Expected: the existing 30 tests and 2 new button tests pass.

- [ ] **Step 2: Build and inspect the Release application**

```bash
xcodebuild clean build \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$PWD"
codesign --verify --deep --strict --verbose=2 EraseA12.app
file EraseA12.app/Contents/MacOS/EraseA12
otool -L EraseA12.app/Contents/MacOS/EraseA12
plutil -lint EraseA12/EraseA12/Resources/*/Localizable.strings
git diff --check
```

Expected: Release build and strict signature pass, the binary is `x86_64 + arm64`, and the known Homebrew OpenSSL dependency remains documented.

- [ ] **Step 3: Update continuity documents**

Record the visible top-right button, callback wiring, new total test count, Release hash, actual launch check, unchanged OpenSSL limitation, and the absence of real-device erase testing. Set the design status to implemented and check off every completed plan step.

- [ ] **Step 4: Review and commit documentation**

```bash
git diff --check
git diff --stat
git status --short --branch
git add HANDOFF.md DEV_LOG.md TODO.md docs/ARCHITECTURE.md \
  docs/superpowers/specs/2026-07-08-erasea12-about-design.md \
  docs/superpowers/plans/2026-07-08-erasea12-about-button.md
git commit -m "docs: record visible About button verification"
```
