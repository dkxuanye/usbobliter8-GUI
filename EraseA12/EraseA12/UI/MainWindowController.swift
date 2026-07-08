import AppKit

// MARK: - Wizard Step

enum WizardStep {
    case waiting
    case confirm
    case executing
    case done
}

// MARK: - MainWindowController

final class MainWindowController: NSWindowController {

    // MARK: - Step View Controllers

    private let waitingVC   = WaitingStepViewController()
    private let confirmVC   = ConfirmStepViewController()
    private let executingVC = ExecutingStepViewController()
    private let doneVC      = DoneStepViewController()

    // MARK: - Core Components

    private let deviceMonitor  = USBDeviceMonitor()
    private let deviceIdentifier = DeviceIdentifier()
    private let ibecResolver   = IBECResolver()

    // MARK: - UI Components

    private let glassBackground = GlassBackgroundView()
    private let stepIndicator  = StepIndicatorView()
    private let containerView = NSView()

    // MARK: - State

    private var currentStep: WizardStep = .waiting
    private var currentChildVC: NSViewController?
    private var currentSerialString: String?

    // MARK: - Init

    init() {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "EraseA12"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)

        setupUI()
        setupCore()
        switchToStep(.waiting)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Glass background
        glassBackground.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassBackground)

        // Step indicator
        stepIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepIndicator)

        // Container for step VCs
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            glassBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassBackground.topAnchor.constraint(equalTo: contentView.topAnchor),
            glassBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stepIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stepIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stepIndicator.heightAnchor.constraint(equalToConstant: 48),

            containerView.topAnchor.constraint(equalTo: stepIndicator.bottomAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Core Setup

    private func setupCore() {
        // Load Devices.plist
        if let plistURL = Bundle.main.url(forResource: "Devices", withExtension: "plist") {
            deviceIdentifier.load(from: plistURL)
        }

        // Set delegates / callbacks
        deviceMonitor.delegate = self

        confirmVC.onConfirm = { [weak self] in
            self?.startObliteration()
        }
        confirmVC.onCancel = { [weak self] in
            self?.resetToWaiting()
        }

        doneVC.onEraseAnother = { [weak self] in
            self?.resetToWaiting()
        }
    }

    // MARK: - Step Switching

    private func switchToStep(_ step: WizardStep) {
        // Remove current child VC
        if let child = currentChildVC {
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        currentStep = step

        // Select the VC for this step
        let newVC: NSViewController
        let indicatorStep: StepIndicatorView.Step

        switch step {
        case .waiting:
            newVC = waitingVC
            indicatorStep = .waiting
        case .confirm:
            newVC = confirmVC
            indicatorStep = .confirm
        case .executing:
            newVC = executingVC
            indicatorStep = .executing
        case .done:
            newVC = doneVC
            indicatorStep = .done
        }

        // Add as child VC using window's contentViewController if available,
        // otherwise just embed the view directly
        if let parentVC = window?.contentViewController {
            parentVC.addChild(newVC)
        }

        // Embed view in container
        newVC.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(newVC.view)

        NSLayoutConstraint.activate([
            newVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            newVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        currentChildVC = newVC
        stepIndicator.currentStep = indicatorStep

        // Start/stop USB monitor based on step
        if step == .waiting {
            deviceMonitor.start()
        } else if step == .executing {
            // Don't stop monitor during execution — we need to detect disconnection
        } else {
            deviceMonitor.stop()
        }
    }

    // MARK: - Obliteration

    private func startObliteration() {
        guard let serialString = currentSerialString else { return }

        switchToStep(.executing)

        let bridge = LibirecoveryBridge()
        let engine = ObliterationEngine(
            bridge: bridge,
            ibecResolver: ibecResolver,
            deviceIdentifier: deviceIdentifier
        )

        // Wire progress callback
        engine.onProgress = { [weak self] state in
            self?.executingVC.updatePhase(state)
        }

        // Execute
        engine.execute(serialString: serialString) { [weak self] result in
            switch result {
            case .done:
                self?.doneVC.configureSuccess()
                self?.switchToStep(.done)
            case .failed(let error):
                self?.doneVC.configureFailure(error: error)
                self?.switchToStep(.done)
            default:
                break
            }
        }
    }

    // MARK: - Reset

    @objc func resetToWaiting() {
        currentSerialString = nil
        deviceMonitor.stop()
        switchToStep(.waiting)
    }

    // MARK: - Show

    func show() {
        window?.center()
        showWindow(self)
        window?.makeKeyAndOrderFront(self)
    }
}

// MARK: - USBDeviceMonitorDelegate

extension MainWindowController: USBDeviceMonitorDelegate {

    func dfuDeviceAppeared(serialString: String) {
        currentSerialString = serialString

        let identification = deviceIdentifier.identify(serialString: serialString)

        switch identification {
        case .recognized(let entry, let isPWND, _):
            let canErase = isPWND && ibecResolver.hasIBEC(codename: entry.ibecCodename)
            confirmVC.configure(
                deviceName: entry.name,
                cpid: entry.cpid,
                bdid: entry.bdid,
                isPWND: isPWND,
                ibecCodename: entry.ibecCodename,
                canErase: canErase
            )
            switchToStep(.confirm)

        case .unsupportedChip(let cpid):
            confirmVC.configure(
                deviceName: L10n.text("device.unsupported", fallback: "不支持的设备"),
                cpid: cpid,
                bdid: 0,
                isPWND: false,
                ibecCodename: "—",
                canErase: false
            )
            switchToStep(.confirm)

        case .unknownBoard(let cpid, let bdid):
            confirmVC.configure(
                deviceName: L10n.text("device.unknown", fallback: "未知设备"),
                cpid: cpid,
                bdid: bdid,
                isPWND: false,
                ibecCodename: "—",
                canErase: false
            )
            switchToStep(.confirm)

        case .unparseable:
            // Ignore unparseable serial strings
            break
        }
    }

    func dfuDeviceDisappeared() {
        if currentStep == .confirm || currentStep == .waiting {
            resetToWaiting()
        }
    }
}
