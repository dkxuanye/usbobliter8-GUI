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
        if #available(macOS 11.0, *) {
            spinner.controlSize = .large
        } else {
            spinner.controlSize = .regular
        }
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
        warningLabel.stringValue = L10n.text("executing.warning", fallback: "请勿断开设备连接")
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
            text = L10n.text("phase.preparing", fallback: "准备中…")
        case .uploading:
            text = L10n.text("phase.uploading", fallback: "正在上传 iBEC…")
        case .booting:
            text = L10n.text("phase.booting", fallback: "正在启动 iBEC…")
        case .waitingRecovery:
            text = L10n.text("phase.waiting_recovery", fallback: "等待恢复模式…")
        case .sendingCommands:
            text = L10n.text("phase.sending_commands", fallback: "正在发送擦除指令…")
        case .rebooting:
            text = L10n.text("phase.rebooting", fallback: "正在重启设备…")
        case .done:
            text = L10n.text("phase.complete", fallback: "已完成")
        case .failed:
            text = L10n.text("phase.failed", fallback: "失败")
        }
        phaseLabel.stringValue = text
    }
}
