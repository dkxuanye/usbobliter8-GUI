import AppKit

final class DoneStepViewController: NSViewController {

    // MARK: - Callback

    var onEraseAnother: (() -> Void)?

    // MARK: - UI Elements

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton()

    // MARK: - State

    private var isSuccess = true

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
        // Icon
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isEditable = false
        view.addSubview(iconView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)

        // Detail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.isEditable = false
        detailLabel.isSelectable = false
        detailLabel.backgroundColor = .clear
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 3
        detailLabel.preferredMaxLayoutWidth = 380
        view.addSubview(detailLabel)

        // Action button
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(actionButtonClicked)
        view.addSubview(actionButton)

        // Layout
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 380),

            actionButton.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 24),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 200),
            actionButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - Configuration

    func configureSuccess() {
        isSuccess = true

        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill",
                                     accessibilityDescription: NSLocalizedString("Success", comment: "Accessibility: success icon"))
            iconView.contentTintColor = .systemGreen
        } else {
            iconView.image = NSImage(named: NSImage.statusAvailableName)
        }

        titleLabel.stringValue = NSLocalizedString("Erase Complete", comment: "Done step: success title")
        titleLabel.textColor = .systemGreen

        detailLabel.stringValue = NSLocalizedString(
            "The device has been successfully erased.",
            comment: "Done step: success detail"
        )

        actionButton.title = NSLocalizedString("Erase Another Device", comment: "Done step: erase another button")
    }

    func configureFailure(error: ObliterationError) {
        isSuccess = false

        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                     accessibilityDescription: NSLocalizedString("Failure", comment: "Accessibility: failure icon"))
            iconView.contentTintColor = .systemRed
        } else {
            iconView.image = NSImage(named: NSImage.statusUnavailableName)
        }

        titleLabel.stringValue = NSLocalizedString("Erase Failed", comment: "Done step: failure title")
        titleLabel.textColor = .systemRed

        detailLabel.stringValue = error.description

        actionButton.title = NSLocalizedString("Try Again", comment: "Done step: try again button")
    }

    // MARK: - Actions

    @objc private func actionButtonClicked() {
        onEraseAnother?()
    }
}
