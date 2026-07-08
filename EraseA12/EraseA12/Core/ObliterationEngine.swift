import Foundation

// MARK: - Protocol

protocol LibirecoveryProtocol {
    func connect(ecid: UInt64) throws
    func disconnect()
    func readSerialString() -> String?
    func getMode() -> Int32
    func sendFile(at path: String) throws
    func sendBuffer(_ data: Data, options: UInt32) throws
    func sendCommand(_ command: String) throws
    func setenv(_ variable: String, _ value: String) throws
    func saveenv() throws
    func reboot() throws
    func reconnect(initialPause: Int32) -> Bool
    func resetCounters() throws
    func finishTransfer() throws
}

// MARK: - LibirecoveryBridge Conformance

extension LibirecoveryBridge: LibirecoveryProtocol {
    // The bridge already implements all required methods.
    // sendBuffer is bridged here from the pointer-based API to Data-based.
    func sendBuffer(_ data: Data, options: UInt32 = 0) throws {
        let count = data.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { buffer.deallocate() }
        data.copyBytes(to: buffer, count: count)
        try sendBuffer(buffer, length: count, options: options)
    }
}

// MARK: - State Machine

enum ObliterationState: Equatable {
    case idle
    case uploading
    case booting
    case waitingRecovery
    case sendingCommands
    case rebooting
    case done
    case failed(ObliterationError)

    static func == (lhs: ObliterationState, rhs: ObliterationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.uploading, .uploading),
             (.booting, .booting),
             (.waitingRecovery, .waitingRecovery),
             (.sendingCommands, .sendingCommands),
             (.rebooting, .rebooting),
             (.done, .done):
            return true
        case (.failed(let l), .failed(let r)):
            return String(describing: l) == String(describing: r)
        default:
            return false
        }
    }
}

// MARK: - Engine

final class ObliterationEngine {

    // MARK: - Configuration

    /// Interval in seconds between recovery-mode reconnection polls.
    var recoveryPollInterval: TimeInterval = 1.0

    /// Maximum seconds to wait for the device to enter recovery mode.
    var recoveryTimeout: TimeInterval = 60.0

    // MARK: - Callbacks

    var onProgress: ((ObliterationState) -> Void)?

    // MARK: - Dependencies

    private let bridge: LibirecoveryProtocol
    private let ibecResolver: IBECResolver
    private let deviceIdentifier: DeviceIdentifier

    // MARK: - Queue

    private let workQueue = DispatchQueue(label: "com.prdgmshift.erasea12.obliteration", qos: .userInitiated)

    // MARK: - Init

    init(bridge: LibirecoveryProtocol,
         ibecResolver: IBECResolver,
         deviceIdentifier: DeviceIdentifier) {
        self.bridge = bridge
        self.ibecResolver = ibecResolver
        self.deviceIdentifier = deviceIdentifier
    }

    // MARK: - Public API

    func execute(serialString: String, completion: @escaping (ObliterationState) -> Void) {
        workQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(.failed(.unknown(underlying: NSError(domain: "ObliterationEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Engine deallocated during execution"])))) }
                return
            }
            let result = self._execute(serialString: serialString)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Private Flow

    private func _execute(serialString: String) -> ObliterationState {

        // 1. Identify device
        let identification = deviceIdentifier.identify(serialString: serialString)

        switch identification {
        case .unparseable:
            return emitFailure(.noDevice)
        case .unsupportedChip(let cpid):
            return emitFailure(.unsupportedDevice(cpid: cpid, bdid: 0))
        case .unknownBoard(let cpid, let bdid):
            return emitFailure(.unsupportedDevice(cpid: cpid, bdid: bdid))
        case .recognized(let entry, let isPWND, let ecid):
            // 2. Check PWND status
            guard isPWND else {
                return emitFailure(.notPWND)
            }

            // 3. Resolve iBEC file
            guard let ibecURL = ibecResolver.resolve(codename: entry.ibecCodename) else {
                return emitFailure(.ibecNotFound(codename: entry.ibecCodename))
            }

            // 4. Connect to device (DFU mode)
            let ecidValue = UInt64(ecid, radix: 16) ?? 0
            do {
                try bridge.connect(ecid: ecidValue)
            } catch {
                return emitFailure(.noDevice)
            }

            // 5. Upload iBEC file
            emit(.uploading)
            do {
                try bridge.sendFile(at: ibecURL.path)
            } catch {
                bridge.disconnect()
                return emitFailure(.uploadFailed(underlying: error))
            }

            // 6. Boot iBEC
            emit(.booting)
            do {
                try bridge.resetCounters()
                try bridge.finishTransfer()
            } catch {
                bridge.disconnect()
                return emitFailure(.bootFailed(underlying: error))
            }

            // 7. Disconnect, wait for Recovery mode
            bridge.disconnect()
            emit(.waitingRecovery)

            let recovered = waitForRecovery(ecid: ecidValue)
            guard recovered else {
                return emitFailure(.recoveryTimeout)
            }

            // 8. Send NVRAM commands
            emit(.sendingCommands)
            do {
                try bridge.setenv("oblit-inprogress", "5")
                try bridge.setenv("auto-boot", "true")
                try bridge.saveenv()
            } catch {
                bridge.disconnect()
                return emitFailure(.commandFailed(underlying: error))
            }

            // 9. Reboot (failure ignored, matching Python behavior)
            emit(.rebooting)
            try? bridge.reboot()

            bridge.disconnect()

            // 10. Done
            emit(.done)
            return .done
        }
    }

    // MARK: - Recovery Wait

    private func waitForRecovery(ecid: UInt64) -> Bool {
        let deadline = Date().addingTimeInterval(recoveryTimeout)

        while Date() < deadline {
            do {
                try bridge.connect(ecid: ecid)
                let mode = bridge.getMode()
                // Recovery mode range: 0x1280 ..<= 0x1283
                if mode >= 0x1280 && mode <= 0x1283 {
                    return true
                }
                bridge.disconnect()
            } catch {
                // Connection failed — device not yet in recovery, keep polling
            }

            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }
            let sleepTime = min(recoveryPollInterval, remaining)
            Thread.sleep(forTimeInterval: sleepTime)
        }

        return false
    }

    // MARK: - State Emission

    @discardableResult
    private func emitFailure(_ error: ObliterationError) -> ObliterationState {
        let state = ObliterationState.failed(error)
        emit(state)
        return state
    }

    private func emit(_ state: ObliterationState) {
        if let onProgress = onProgress {
            DispatchQueue.main.async {
                onProgress(state)
            }
        }
    }
}
