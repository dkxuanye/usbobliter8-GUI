import AppKit

final class WaitingStepViewController: NSViewController {

    // MARK: - UI Elements

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let contentStackView = NSStackView()

    // MARK: - Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        startPulseAnimation()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        stopPulseAnimation()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Content stack
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.orientation = .vertical
        contentStackView.alignment = .centerX
        contentStackView.spacing = 0
        view.addSubview(contentStackView)

        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .secondaryLabelColor
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "cable.connector",
                                     accessibilityDescription: L10n.text("accessibility.usb_cable", fallback: "USB 线缆"))
            iconView.symbolConfiguration = .init(pointSize: 64, weight: .regular)
        } else {
            // Fallback: use a generic image or empty state
            iconView.image = NSImage(named: NSImage.networkName)
        }
        iconView.isEditable = false
        contentStackView.addArrangedSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = L10n.text("waiting.title", fallback: "等待设备")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.backgroundColor = .clear
        titleLabel.alignment = .center
        contentStackView.addArrangedSubview(titleLabel)

        // Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.stringValue = L10n.text(
            "waiting.subtitle",
            fallback: "请使用 usbliter8 将设备进入 PWND DFU 模式"
        )
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.isEditable = false
        subtitleLabel.isSelectable = false
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.alignment = .center
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 360
        contentStackView.addArrangedSubview(subtitleLabel)

        contentStackView.setCustomSpacing(16, after: iconView)
        contentStackView.setCustomSpacing(8, after: titleLabel)

        // Layout
        NSLayoutConstraint.activate([
            contentStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 4),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            contentStackView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 16),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24),

            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48)
        ])
    }

    // MARK: - Pulse Animation

    func startPulseAnimation() {
        if iconView.layer == nil {
            iconView.wantsLayer = true
        }

        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1.0, 0.4, 1.0]
        animation.keyTimes = [0.0, 0.5, 1.0]
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        iconView.layer?.add(animation, forKey: "pulseAnimation")
    }

    func stopPulseAnimation() {
        iconView.layer?.removeAnimation(forKey: "pulseAnimation")
        iconView.layer?.opacity = 1.0
    }
}
