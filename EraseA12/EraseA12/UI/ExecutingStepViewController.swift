import AppKit

final class ExecutingStepViewController: NSViewController {

    // MARK: - UI Elements

    private let spinner = NSProgressIndicator()
    private let phaseLabel = NSTextField(labelWithString: "")
    private let warningLabel = NSTextField(labelWithString: "")

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
        spinner.startAnimation(nil)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        spinner.stopAnimation(nil)
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Spinner
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .large
        view.addSubview(spinner)

        // Phase label
        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        phaseLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        phaseLabel.textColor = .labelColor
        phaseLabel.alignment = .center
        phaseLabel.isEditable = false
        phaseLabel.isSelectable = false
        phaseLabel.backgroundColor = .clear
        view.addSubview(phaseLabel)

        // Warning
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.stringValue = NSLocalizedString(
            "Do not disconnect the device",
            comment: "Executing step: warning not to disconnect"
        )
        warningLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        warningLabel.textColor = .secondaryLabelColor
        warningLabel.alignment = .center
        warningLabel.isEditable = false
        warningLabel.isSelectable = false
        warningLabel.backgroundColor = .clear
        view.addSubview(warningLabel)

        // Layout
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),

            phaseLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            phaseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            warningLabel.topAnchor.constraint(equalTo: phaseLabel.bottomAnchor, constant: 12),
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Phase Update

    func updatePhase(_ state: ObliterationState) {
        let text: String
        switch state {
        case .idle:
            text = NSLocalizedString("Preparing…", comment: "Executing step: idle phase")
        case .uploading:
            text = NSLocalizedString("Uploading iBEC…", comment: "Executing step: uploading phase")
        case .booting:
            text = NSLocalizedString("Booting iBEC…", comment: "Executing step: booting phase")
        case .waitingRecovery:
            text = NSLocalizedString("Waiting for recovery mode…", comment: "Executing step: waiting recovery phase")
        case .sendingCommands:
            text = NSLocalizedString("Sending erase commands…", comment: "Executing step: sending commands phase")
        case .rebooting:
            text = NSLocalizedString("Rebooting device…", comment: "Executing step: rebooting phase")
        case .done:
            text = NSLocalizedString("Complete!", comment: "Executing step: done phase")
        case .failed:
            text = NSLocalizedString("Failed", comment: "Executing step: failed phase")
        }
        phaseLabel.stringValue = text
    }
}
