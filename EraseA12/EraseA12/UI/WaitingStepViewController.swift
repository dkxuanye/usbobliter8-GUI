import AppKit

final class WaitingStepViewController: NSViewController {

    // MARK: - UI Elements

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

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
        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .secondaryLabelColor
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "cable.connector",
                                     accessibilityDescription: NSLocalizedString("USB Cable", comment: "Accessibility: cable connector icon"))
            iconView.symbolConfiguration = .init(pointSize: 64, weight: .regular)
        } else {
            // Fallback: use a generic image or empty state
            iconView.image = NSImage(named: NSImage.networkName)
        }
        iconView.isEditable = false
        view.addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = NSLocalizedString("Waiting for Device", comment: "Waiting step: title")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.backgroundColor = .clear
        titleLabel.alignment = .center
        view.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.stringValue = NSLocalizedString(
            "Please put your device into PWND DFU mode using usbliter8",
            comment: "Waiting step: subtitle instruction"
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
        view.addSubview(subtitleLabel)

        // Layout
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
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
