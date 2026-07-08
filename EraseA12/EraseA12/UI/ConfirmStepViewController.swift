import AppKit

final class ConfirmStepViewController: NSViewController {

    // MARK: - Callback

    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - UI Elements

    private let deviceNameLabel = NSTextField(labelWithString: "")
    private let chipInfoLabel = NSTextField(labelWithString: "")
    private let pwndStatusLabel = NSTextField(labelWithString: "")
    private let ibecLabel = NSTextField(labelWithString: "")
    private let warningLabel = NSTextField(labelWithString: "")
    private let eraseButton = NSButton()
    private let cancelButton = NSButton()

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

    // MARK: - UI Setup

    private func setupUI() {
        // Device name
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceNameLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        deviceNameLabel.textColor = .labelColor
        deviceNameLabel.alignment = .center
        view.addSubview(deviceNameLabel)

        // Chip info (CPID/BDID)
        chipInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        chipInfoLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        chipInfoLabel.textColor = .secondaryLabelColor
        chipInfoLabel.alignment = .center
        view.addSubview(chipInfoLabel)

        // PWND status
        pwndStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        pwndStatusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        pwndStatusLabel.alignment = .center
        view.addSubview(pwndStatusLabel)

        // iBEC codename
        ibecLabel.translatesAutoresizingMaskIntoConstraints = false
        ibecLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        ibecLabel.textColor = .tertiaryLabelColor
        ibecLabel.alignment = .center
        view.addSubview(ibecLabel)

        // Warning
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.stringValue = NSLocalizedString(
            "⚠️ This will erase ALL data on this device. This action cannot be undone.",
            comment: "Confirm step: warning message"
        )
        warningLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        warningLabel.textColor = .systemRed
        warningLabel.alignment = .center
        warningLabel.lineBreakMode = .byWordWrapping
        warningLabel.maximumNumberOfLines = 2
        warningLabel.preferredMaxLayoutWidth = 380
        view.addSubview(warningLabel)

        // Erase button
        eraseButton.translatesAutoresizingMaskIntoConstraints = false
        eraseButton.title = NSLocalizedString("Erase Device", comment: "Confirm step: erase button")
        eraseButton.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        eraseButton.bezelStyle = .rounded
        eraseButton.wantsLayer = true
        eraseButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        eraseButton.layer?.cornerRadius = 6
        eraseButton.contentTintColor = .white
        eraseButton.isBordered = false
        eraseButton.target = self
        eraseButton.action = #selector(eraseButtonClicked)
        view.addSubview(eraseButton)

        // Cancel button
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.title = NSLocalizedString("Cancel", comment: "Confirm step: cancel button")
        cancelButton.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        view.addSubview(cancelButton)

        // Layout
        NSLayoutConstraint.activate([
            deviceNameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            deviceNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            chipInfoLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 6),
            chipInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            pwndStatusLabel.topAnchor.constraint(equalTo: chipInfoLabel.bottomAnchor, constant: 8),
            pwndStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            ibecLabel.topAnchor.constraint(equalTo: pwndStatusLabel.bottomAnchor, constant: 6),
            ibecLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            warningLabel.topAnchor.constraint(equalTo: ibecLabel.bottomAnchor, constant: 20),
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            warningLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 380),

            eraseButton.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 24),
            eraseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -60),
            eraseButton.widthAnchor.constraint(equalToConstant: 140),
            eraseButton.heightAnchor.constraint(equalToConstant: 36),

            cancelButton.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 24),
            cancelButton.leadingAnchor.constraint(equalTo: eraseButton.trailingAnchor, constant: 12),
            cancelButton.centerYAnchor.constraint(equalTo: eraseButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - Configuration

    func configure(deviceName: String, cpid: String, bdid: Int, isPWND: Bool, ibecCodename: String, canErase: Bool) {
        deviceNameLabel.stringValue = deviceName

        chipInfoLabel.stringValue = String(format: NSLocalizedString(
            "CPID:%@ BDID:%d",
            comment: "Confirm step: chip info format"
        ), cpid, bdid)

        if isPWND {
            pwndStatusLabel.stringValue = "✓ " + NSLocalizedString(
                "PWND",
                comment: "Confirm step: PWND status positive"
            )
            pwndStatusLabel.textColor = .systemGreen
        } else {
            pwndStatusLabel.stringValue = "✗ " + NSLocalizedString(
                "Not PWND",
                comment: "Confirm step: PWND status negative"
            )
            pwndStatusLabel.textColor = .systemRed
        }

        ibecLabel.stringValue = String(format: NSLocalizedString(
            "iBEC: %@",
            comment: "Confirm step: iBEC codename"
        ), ibecCodename)

        eraseButton.isEnabled = canErase
        eraseButton.alphaValue = canErase ? 1.0 : 0.5
    }

    // MARK: - Actions

    @objc private func eraseButtonClicked() {
        onConfirm?()
    }

    @objc private func cancelButtonClicked() {
        onCancel?()
    }
}
