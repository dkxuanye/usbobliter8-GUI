import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindowController: MainWindowController?
    private var aboutWindowController: AboutWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let controller = MainWindowController()
        controller.onShowAbout = { [weak self] in
            self?.showAboutWindow(nil)
        }
        controller.show()
        mainWindowController = controller
    }

    func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "EraseA12", action: nil, keyEquivalent: "")
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
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - About Window

struct AboutInformation {
    let appName: String
    let version: String
    let build: String

    init(appName: String, version: String, build: String) {
        self.appName = appName
        self.version = version
        self.build = build
    }

    init(infoDictionary: [String: Any]) {
        appName = infoDictionary["CFBundleName"] as? String ?? "EraseA12"
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "1.0.0"
        build = infoDictionary["CFBundleVersion"] as? String ?? "1"
    }

    init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    var versionText: String {
        L10n.format(
            "about.version_format",
            fallback: "版本 %@（%@）",
            version,
            build
        )
    }
}

final class AboutWindowController: NSWindowController {
    static let originalProjectURL = URL(string: "https://github.com/overcast302/usbobliter8")!
    static let developerWebsiteURL = URL(string: "https://www.dkxuanye.cn")!

    init(information: AboutInformation = AboutInformation()) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("about.title", fallback: "关于 EraseA12")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupContent(information: information)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent(information: AboutInformation) {
        guard let contentView = window?.contentView else { return }

        let background = GlassBackgroundView()
        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let icon = NSImageView(image: NSApplication.shared.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 72),
            icon.heightAnchor.constraint(equalToConstant: 72)
        ])

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(makeLabel(information.appName, size: 24, weight: .semibold))
        stack.addArrangedSubview(makeLabel(information.versionText, size: 13, weight: .regular))
        stack.addArrangedSubview(
            makeLinkButton(
                L10n.text("about.original_author", fallback: "原项目作者：overcast302"),
                action: #selector(openOriginalProject)
            )
        )
        stack.addArrangedSubview(
            makeLabel(
                L10n.text("about.developer", fallback: "由 玄烨品果开发"),
                size: 13,
                weight: .medium
            )
        )
        stack.addArrangedSubview(
            makeLinkButton(
                L10n.text("about.website", fallback: "www.dkxuanye.cn"),
                action: #selector(openDeveloperWebsite)
            )
        )
        stack.addArrangedSubview(
            makeLabel(
                L10n.text("about.copyright", fallback: "Copyright © 2026 overcast302"),
                size: 11,
                weight: .regular,
                color: .secondaryLabelColor
            )
        )
        stack.addArrangedSubview(
            makeLabel(
                L10n.text("about.license", fallback: "MIT License"),
                size: 11,
                weight: .regular,
                color: .secondaryLabelColor
            )
        )

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 8),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28)
        ])
    }

    private func makeLabel(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        return label
    }

    private func makeLinkButton(_ title: String, action: Selector) -> NSButton {
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
