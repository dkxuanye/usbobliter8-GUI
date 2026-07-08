import XCTest
@testable import EraseA12

// MARK: - Mock

final class MockLibirecovery: LibirecoveryProtocol {

    // MARK: - Call tracking

    var connectCallCount = 0
    var disconnectCallCount = 0
    var readSerialStringCallCount = 0
    var getModeCallCount = 0
    var sendFileCallCount = 0
    var sendFileLastPath: String?
    var sendBufferCallCount = 0
    var sendBufferLastData: Data?
    var sendCommandCallCount = 0
    var sendCommandLastCommand: String?
    var setenvCallCount = 0
    var setenvHistory: [(variable: String, value: String)] = []
    var saveenvCallCount = 0
    var rebootCallCount = 0
    var reconnectCallCount = 0
    var resetCountersCallCount = 0
    var finishTransferCallCount = 0

    // MARK: - Control flags

    var shouldFailUpload = false
    var shouldFailRecoveryConnect = false
    var shouldFailSetenv = false
    var shouldFailReboot = false
    var shouldFailBoot = false

    /// When true, the second call to `connect` returns recovery mode (0x1280) on `getMode()`.
    var recoveryModeOnConnect = true

    /// Serial string returned by `readSerialString()`.
    var serialString: String? = "CPID:8020 BDID:0A ECID:0000000000000001 PWND:[checkra1n]"

    // MARK: - Internal state

    private var isConnected = false
    private var connectAttempt = 0

    // MARK: - LibirecoveryProtocol

    func connect(ecid: UInt64) throws {
        connectAttempt += 1
        connectCallCount += 1

        if connectAttempt == 1 {
            // First connect: DFU mode — always succeeds unless recovery connect is forced to fail
            isConnected = true
            return
        }

        // Second connect: Recovery mode
        if shouldFailRecoveryConnect {
            throw LibirecoveryBridge.Error.unableToConnect
        }
        isConnected = true
    }

    func disconnect() {
        disconnectCallCount += 1
        isConnected = false
    }

    func readSerialString() -> String? {
        readSerialStringCallCount += 1
        return serialString
    }

    func getMode() -> Int32 {
        getModeCallCount += 1
        guard isConnected else { return -1 }

        // First connection is DFU mode, second is Recovery mode
        if connectAttempt == 2 && recoveryModeOnConnect {
            return 0x1280
        }
        return -1
    }

    func sendFile(at path: String) throws {
        sendFileCallCount += 1
        sendFileLastPath = path
        if shouldFailUpload {
            throw LibirecoveryBridge.Error.usbUpload
        }
    }

    func sendBuffer(_ data: Data, options: UInt32) throws {
        sendBufferCallCount += 1
        sendBufferLastData = data
    }

    func sendCommand(_ command: String) throws {
        sendCommandCallCount += 1
        sendCommandLastCommand = command
    }

    func setenv(_ variable: String, _ value: String) throws {
        setenvCallCount += 1
        setenvHistory.append((variable: variable, value: value))
        if shouldFailSetenv {
            throw LibirecoveryBridge.Error.unsupported
        }
    }

    func saveenv() throws {
        saveenvCallCount += 1
        if shouldFailSetenv {
            throw LibirecoveryBridge.Error.unsupported
        }
    }

    func reboot() throws {
        rebootCallCount += 1
        if shouldFailReboot {
            throw LibirecoveryBridge.Error.unsupported
        }
    }

    func reconnect(initialPause: Int32) -> Bool {
        reconnectCallCount += 1
        return true
    }

    func resetCounters() throws {
        resetCountersCallCount += 1
        if shouldFailBoot {
            throw LibirecoveryBridge.Error.usbStatus
        }
    }

    func finishTransfer() throws {
        finishTransferCallCount += 1
        if shouldFailBoot {
            throw LibirecoveryBridge.Error.usbStatus
        }
    }
}

// MARK: - Tests

final class ObliterationEngineTests: XCTestCase {

    var mockBridge: MockLibirecovery!
    var ibecResolver: IBECResolver!
    var deviceIdentifier: DeviceIdentifier!
    var engine: ObliterationEngine!

    var bundleDir: URL!
    var plistURL: URL!
    var tempRoot: URL!

    override func setUp() {
        super.setUp()

        mockBridge = MockLibirecovery()

        // Set up DeviceIdentifier with test plist
        deviceIdentifier = DeviceIdentifier()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ObliterationEngineTests-\(UUID().uuidString)")
        let plistDir = tempRoot.appendingPathComponent("plist")
        try? FileManager.default.createDirectory(at: plistDir, withIntermediateDirectories: true)
        plistURL = plistDir.appendingPathComponent("Devices.plist")

        let testEntries: [[String: Any]] = [
            [
                "cpid": "0x8020",
                "bdid": 10,
                "name": "iPhone XS Max",
                "ibecCodename": "d331"
            ],
            [
                "cpid": "0x8030",
                "bdid": 4,
                "name": "iPhone 11",
                "ibecCodename": "n104"
            ]
        ]

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: testEntries,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL)
        } catch {
            XCTFail("Failed to create test plist: \(error)")
        }
        XCTAssertTrue(deviceIdentifier.load(from: plistURL))

        // Set up IBECResolver with test directories
        bundleDir = tempRoot.appendingPathComponent("bundle")
        let userDir = tempRoot.appendingPathComponent("user")
        try? FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        ibecResolver = IBECResolver(bundleDirOverride: bundleDir, userDirOverride: userDir)

        // Create a dummy iBEC file for the test codename
        let ibecFilename = IBECResolver.ibecFilename(codename: "d331")
        let ibecFile = bundleDir.appendingPathComponent(ibecFilename)
        try? Data("fake-ibec".utf8).write(to: ibecFile)

        engine = ObliterationEngine(
            bridge: mockBridge,
            ibecResolver: ibecResolver,
            deviceIdentifier: deviceIdentifier
        )

        // Use short timeouts for tests
        engine.recoveryPollInterval = 0.05
        engine.recoveryTimeout = 0.5
    }

    override func tearDown() {
        if let tempRoot = tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        mockBridge = nil
        ibecResolver = nil
        deviceIdentifier = nil
        engine = nil
        super.tearDown()
    }

    // MARK: - Happy Path

    func testSuccessfulObliteration() {
        let expectation = XCTestExpectation(description: "Obliteration completes")

        let serialString = "CPID:8020 BDID:0A ECID:0000000000000001 PWND:[checkra1n]"

        var progressStates: [ObliterationState] = []
        engine.onProgress = { state in
            progressStates.append(state)
        }

        engine.execute(serialString: serialString) { finalState in
            switch finalState {
            case .done:
                // Success
                break
            case .failed(let error):
                XCTFail("Expected .done but got .failed(\(error))")
            default:
                XCTFail("Expected .done but got \(finalState)")
            }

            // Verify all methods called in order
            XCTAssertEqual(self.mockBridge.connectCallCount, 2, "Should connect twice: DFU then Recovery")
            XCTAssertEqual(self.mockBridge.disconnectCallCount, 2, "Should disconnect after boot and after reboot")
            XCTAssertEqual(self.mockBridge.sendFileCallCount, 1, "Should send iBEC file once")
            XCTAssertEqual(self.mockBridge.resetCountersCallCount, 1, "Should reset counters once")
            XCTAssertEqual(self.mockBridge.finishTransferCallCount, 1, "Should finish transfer once")
            XCTAssertEqual(self.mockBridge.setenvCallCount, 2, "Should setenv twice (oblit-inprogress, auto-boot)")
            XCTAssertEqual(self.mockBridge.saveenvCallCount, 1, "Should saveenv once")
            XCTAssertEqual(self.mockBridge.rebootCallCount, 1, "Should reboot once")

            // Verify setenv arguments
            XCTAssertEqual(self.mockBridge.setenvHistory.count, 2)
            XCTAssertEqual(self.mockBridge.setenvHistory[0].variable, "oblit-inprogress")
            XCTAssertEqual(self.mockBridge.setenvHistory[0].value, "5")
            XCTAssertEqual(self.mockBridge.setenvHistory[1].variable, "auto-boot")
            XCTAssertEqual(self.mockBridge.setenvHistory[1].value, "true")

            // Verify iBEC file path was sent
            XCTAssertNotNil(self.mockBridge.sendFileLastPath)
            XCTAssertTrue(self.mockBridge.sendFileLastPath?.contains("iBEC.d331") ?? false)

            // Verify progress states were emitted in order
            let expectedProgress: [ObliterationState] = [
                .uploading,
                .booting,
                .waitingRecovery,
                .sendingCommands,
                .rebooting,
                .done
            ]
            XCTAssertEqual(progressStates, expectedProgress, "Progress states should match expected flow")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Not PWND

    func testFailsWhenNotPWND() {
        let expectation = XCTestExpectation(description: "Obliteration fails when not PWND")

        // Serial string without PWND
        let serialString = "CPID:8020 BDID:0A ECID:0000000000000001"

        engine.execute(serialString: serialString) { finalState in
            switch finalState {
            case .failed(let error):
                if case .notPWND = error {
                    // Expected
                } else {
                    XCTFail("Expected .notPWND but got .failed(\(error))")
                }
            default:
                XCTFail("Expected .failed but got \(finalState)")
            }

            // Should not have connected or sent anything
            XCTAssertEqual(self.mockBridge.connectCallCount, 0)
            XCTAssertEqual(self.mockBridge.sendFileCallCount, 0)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Unsupported Device

    func testFailsWhenUnsupportedDevice() {
        let expectation = XCTestExpectation(description: "Obliteration fails for unsupported device")

        // CPID 0x8015 is not in the supported set
        let serialString = "CPID:8015 BDID:01 ECID:0000000000000004 PWND:[checkra1:[checkra1n]"

        engine.execute(serialString: serialString) { finalState in
            switch finalState {
            case .failed(let error):
                if case .unsupportedDevice(let cpid, _) = error {
                    XCTAssertEqual(cpid, "0x8015")
                } else {
                    XCTFail("Expected .unsupportedDevice but got .failed(\(error))")
                }
            default:
                XCTFail("Expected .failed but got \(finalState)")
            }

            XCTAssertEqual(self.mockBridge.connectCallCount, 0)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Reboot Failure Ignored

    func testRebootFailureIsIgnored() {
        let expectation = XCTestExpectation(description: "Reboot failure is ignored, engine returns .done")

        mockBridge.shouldFailReboot = true

        let serialString = "CPID:8020 BDID:0A ECID:0000000000000001 PWND:[checkra1n]"

        engine.execute(serialString: serialString) { finalState in
            switch finalState {
            case .done:
                // Expected — reboot failure is ignored
                break
            case .failed(let error):
                XCTFail("Expected .done but got .failed(\(error))")
            default:
                XCTFail("Expected .done but got \(finalState)")
            }

            // Reboot was attempted even though it failed
            XCTAssertEqual(self.mockBridge.rebootCallCount, 1)
            // All other steps should have completed
            XCTAssertEqual(self.mockBridge.sendFileCallCount, 1)
            XCTAssertEqual(self.mockBridge.setenvCallCount, 2)
            XCTAssertEqual(self.mockBridge.saveenvCallCount, 1)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
