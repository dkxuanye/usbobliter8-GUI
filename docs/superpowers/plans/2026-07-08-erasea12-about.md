# EraseA12 About Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standard macOS “关于 EraseA12” menu item and an informational window that preserves the original author's MIT copyright while crediting the native GUI developer.

**Architecture:** `AppDelegate` owns the application menu and retains one `AboutWindowController`. The new controller owns only the about-window presentation and immutable HTTPS destinations; display text uses the existing forced Simplified Chinese localization path.

**Tech Stack:** Swift 5, AppKit, XCTest, xcodegen, Xcode 14.3, macOS 10.15+

## Global Constraints

- Keep the deployment target at macOS 10.15.
- Add no third-party dependencies.
- Preserve `Copyright (c) 2026 overcast302` and the MIT License.
- Display `由 玄烨品果开发` and link `www.dkxuanye.cn` to `https://www.dkxuanye.cn`.
- Do not connect to a device or execute the destructive erase workflow.
- Treat `EraseA12/project.yml` as the project source of truth; this change adds no source files, so the generated project needs no membership edit.

---

### Task 1: About window content and links

**Files:**
- Modify: `EraseA12/EraseA12/App/AppDelegate.swift`
- Modify: `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift`
- Modify: `EraseA12/EraseA12/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `EraseA12/EraseA12/Resources/en.lproj/Localizable.strings`

**Interfaces:**
- Produces: `AboutInformation.init(appName:version:build:)`, `AboutInformation.init(bundle:)`, and `AboutWindowController.init(information:)`.
- Produces: `AboutWindowController.originalProjectURL` and `AboutWindowController.developerWebsiteURL` as fixed HTTPS URLs.

- [x] **Step 1: Write failing content and URL tests**

```swift
func testAboutWindowShowsCopyrightAndDeveloperCredits() {
    let information = AboutInformation(appName: "EraseA12", version: "1.2.3", build: "45")
    let controller = AboutWindowController(information: information)
    let texts = Self.displayTexts(in: controller.window!.contentView!)

    XCTAssertTrue(texts.contains("EraseA12"))
    XCTAssertTrue(texts.contains("版本 1.2.3（45）"))
    XCTAssertTrue(texts.contains("原项目作者：overcast302"))
    XCTAssertTrue(texts.contains("由 玄烨品果开发"))
    XCTAssertTrue(texts.contains("www.dkxuanye.cn"))
    XCTAssertTrue(texts.contains("Copyright © 2026 overcast302"))
    XCTAssertTrue(texts.contains("MIT License"))
}

func testAboutWindowUsesFixedHTTPSLinks() {
    XCTAssertEqual(AboutWindowController.originalProjectURL.absoluteString,
                   "https://github.com/overcast302/usbobliter8")
    XCTAssertEqual(AboutWindowController.developerWebsiteURL.absoluteString,
                   "https://www.dkxuanye.cn")
}
```

- [x] **Step 2: Verify the tests fail**

Run:

```bash
xcodebuild test -project EraseA12/EraseA12.xcodeproj -scheme EraseA12 \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:EraseA12Tests/StepIndicatorViewTests
```

Expected: compilation fails because `AboutInformation` and `AboutWindowController` do not exist.

- [x] **Step 3: Add localized strings and minimal controller implementation**

Add Simplified Chinese keys for the title, version format, original author, developer credit, website, copyright, and license. Add corresponding English reference keys to preserve string-table parity.

Implement:

```swift
struct AboutInformation {
    let appName: String
    let version: String
    let build: String

    init(appName: String, version: String, build: String) {
        self.appName = appName
        self.version = version
        self.build = build
    }

    init(bundle: Bundle = .main) {
        let info = bundle.infoDictionary ?? [:]
        appName = info["CFBundleName"] as? String ?? "EraseA12"
        version = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        build = info["CFBundleVersion"] as? String ?? "1"
    }

    var versionText: String {
        L10n.format("about.version_format", fallback: "版本 %@（%@）", version, build)
    }
}

final class AboutWindowController: NSWindowController {
    static let originalProjectURL = URL(string: "https://github.com/overcast302/usbobliter8")!
    static let developerWebsiteURL = URL(string: "https://www.dkxuanye.cn")!

    init(information: AboutInformation = AboutInformation()) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("about.title", fallback: "关于 EraseA12")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupContent(information: information)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupContent(information: AboutInformation) {
        guard let contentView = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView(image: NSApplication.shared.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 72),
            icon.heightAnchor.constraint(equalToConstant: 72)
        ])

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label(information.appName, size: 24, weight: .semibold))
        stack.addArrangedSubview(label(information.versionText, size: 13, weight: .regular))
        stack.addArrangedSubview(linkButton(
            L10n.text("about.original_author", fallback: "原项目作者：overcast302"),
            action: #selector(openOriginalProject)
        ))
        stack.addArrangedSubview(label(
            L10n.text("about.developer", fallback: "由 玄烨品果开发"),
            size: 13,
            weight: .medium
        ))
        stack.addArrangedSubview(linkButton("www.dkxuanye.cn", action: #selector(openDeveloperWebsite)))
        stack.addArrangedSubview(label("Copyright © 2026 overcast302", size: 11, weight: .regular))
        stack.addArrangedSubview(label("MIT License", size: 11, weight: .regular))

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28)
        ])
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.alignment = .center
        field.textColor = .labelColor
        return field
    }

    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 13)
        button.contentTintColor = .linkColor
        return button
    }

    @objc private func openOriginalProject() {
        NSWorkspace.shared.open(Self.originalProjectURL)
    }

    @objc private func openDeveloperWebsite() {
        NSWorkspace.shared.open(Self.developerWebsiteURL)
    }
}
```

- [x] **Step 4: Run focused tests and string-table lint**

Run the focused `xcodebuild test` command from Step 2 and:

```bash
plutil -lint EraseA12/EraseA12/Resources/*/Localizable.strings
```

Expected: focused tests pass and both string tables report `OK`.

### Task 2: Standard application menu integration

**Files:**
- Modify: `EraseA12/EraseA12/App/AppDelegate.swift`
- Modify: `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift`

**Interfaces:**
- Consumes: `AboutWindowController.init(information:)` from Task 1.
- Produces: `AppDelegate.makeMainMenu() -> NSMenu` and `AppDelegate.showAboutWindow(_:)`.

- [x] **Step 1: Write the failing application-menu test**

```swift
func testApplicationMenuContainsAboutItem() {
    let delegate = AppDelegate()
    let menu = delegate.makeMainMenu()
    let appMenu = menu.items.first?.submenu

    XCTAssertNotNil(appMenu?.items.first { $0.title == "关于 EraseA12" })
}
```

- [x] **Step 2: Run the focused test and verify it fails**

Run the Task 1 focused `xcodebuild test` command.

Expected: compilation fails because `makeMainMenu()` does not exist.

- [x] **Step 3: Add the menu and retained about controller**

Implement in `AppDelegate`:

```swift
private var aboutWindowController: AboutWindowController?

func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = makeMainMenu()
    let controller = MainWindowController()
    controller.show()
    mainWindowController = controller
}

func makeMainMenu() -> NSMenu {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu(title: "EraseA12")

    let aboutItem = NSMenuItem(
        title: L10n.text("about.menu_title", fallback: "关于 EraseA12"),
        action: #selector(showAboutWindow(_:)),
        keyEquivalent: ""
    )
    aboutItem.target = self
    appMenu.addItem(aboutItem)
    appMenu.addItem(.separator())

    let quitItem = NSMenuItem(
        title: L10n.text("menu.quit", fallback: "退出 EraseA12"),
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )
    quitItem.target = NSApp
    appMenu.addItem(quitItem)

    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)
    return mainMenu
}

@objc func showAboutWindow(_ sender: Any?) {
    if aboutWindowController == nil {
        aboutWindowController = AboutWindowController()
    }
    aboutWindowController?.showWindow(sender)
    aboutWindowController?.window?.center()
    aboutWindowController?.window?.makeKeyAndOrderFront(sender)
}
```

- [x] **Step 4: Run focused tests**

Expected: all `StepIndicatorViewTests` pass.

### Task 3: Full verification and durable handoff

**Files:**
- Modify: `HANDOFF.md`
- Modify: `DEV_LOG.md`
- Modify: `TODO.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/superpowers/specs/2026-07-08-erasea12-about-design.md`

**Interfaces:**
- Consumes: completed About window and menu integration.
- Produces: verified Release app and updated project continuity records.

- [x] **Step 1: Run the full test suite**

```bash
xcodebuild test -project EraseA12/EraseA12.xcodeproj -scheme EraseA12 \
  -configuration Debug -destination 'platform=macOS'
```

Expected: all existing 26 tests plus the new About tests pass.

- [x] **Step 2: Build and inspect the Release app**

```bash
xcodebuild clean build -project EraseA12/EraseA12.xcodeproj -scheme EraseA12 \
  -configuration Release CONFIGURATION_BUILD_DIR="$PWD"
codesign --verify --deep --strict --verbose=2 EraseA12.app
file EraseA12.app/Contents/MacOS/EraseA12
otool -L EraseA12.app/Contents/MacOS/EraseA12
plutil -lint EraseA12/EraseA12/Resources/*/Localizable.strings
git diff --check
```

Expected: build and strict signature pass; the executable remains universal; the known Homebrew OpenSSL dependency is reported honestly.

- [x] **Step 3: Update handoff documents**

Record the menu, about-window content, new test count, Release verification, unchanged OpenSSL limitation, and the fact that no device-side erase test ran. Mark the design status as implemented.

- [x] **Step 4: Review the final diff**

```bash
git diff --stat
git diff --check
git status --short --branch
```

Expected: only the About feature, localization, tests, plan/spec status, and required handoff updates are changed; generated app artifacts remain ignored.
