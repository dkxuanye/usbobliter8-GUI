import XCTest
@testable import EraseA12

final class DeviceIdentifierTests: XCTestCase {

    var identifier: DeviceIdentifier!
    var plistURL: URL!

    override func setUp() {
        super.setUp()
        identifier = DeviceIdentifier()

        // Create a minimal in-memory test plist
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceIdentifierTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        plistURL = tempDir.appendingPathComponent("Devices.plist")

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
    }

    override func tearDown() {
        if let url = plistURL {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: dir)
        }
        identifier = nil
        plistURL = nil
        super.tearDown()
    }

    // MARK: - Recognized PWND device

    func testRecognizedPWNDDevice() {
        XCTAssertTrue(identifier.load(from: plistURL))

        let result = identifier.identify(serialString: "CPID:8020 BDID:0A ECID:0000000000000001 PWND:[checkra1n]")
        switch result {
        case .recognized(let entry, let isPWND, let ecid):
            XCTAssertEqual(entry.name, "iPhone XS Max")
            XCTAssertEqual(entry.ibecCodename, "d331")
            XCTAssertEqual(entry.cpid, "0x8020")
            XCTAssertEqual(entry.bdid, 10)
            XCTAssertTrue(isPWND)
            XCTAssertEqual(ecid, "0000000000000001")
        default:
            XCTFail("Expected .recognized, got \(result)")
        }
    }

    // MARK: - Recognized not-PWND device

    func testRecognizedNotPWNDDevice() {
        XCTAssertTrue(identifier.load(from: plistURL))

        let result = identifier.identify(serialString: "CPID:8030 BDID:04 ECID:0000000000000002")
        switch result {
        case .recognized(let entry, let isPWND, let ecid):
            XCTAssertEqual(entry.name, "iPhone 11")
            XCTAssertEqual(entry.ibecCodename, "n104")
            XCTAssertFalse(isPWND)
            XCTAssertEqual(ecid, "0000000000000002")
        default:
            XCTFail("Expected .recognized, got \(result)")
        }
    }

    // MARK: - Unknown board (valid CPID, unknown BDID)

    func testUnknownBoard() {
        XCTAssertTrue(identifier.load(from: plistURL))

        let result = identifier.identify(serialString: "CPID:8020 BDID:FF ECID:0000000000000003")
        switch result {
        case .unknownBoard(let cpid, let bdid):
            XCTAssertEqual(cpid, "0x8020")
            XCTAssertEqual(bdid, 0xFF)
        default:
            XCTFail("Expected .unknownBoard, got \(result)")
        }
    }

    // MARK: - Unsupported chip

    func testUnsupportedChip() {
        XCTAssertTrue(identifier.load(from: plistURL))

        let result = identifier.identify(serialString: "CPID:8015 BDID:01 ECID:0000000000000004")
        switch result {
        case .unsupportedChip(let cpid):
            XCTAssertEqual(cpid, "0x8015")
        default:
            XCTFail("Expected .unsupportedChip, got \(result)")
        }
    }

    // MARK: - Unparseable (nil, empty, missing BDID)

    func testUnparseableNil() {
        let result = identifier.identify(serialString: nil)
        if case .unparseable = result {
            // expected
        } else {
            XCTFail("Expected .unparseable for nil, got \(result)")
        }
    }

    func testUnparseableEmpty() {
        let result = identifier.identify(serialString: "")
        if case .unparseable = result {
            // expected
        } else {
            XCTFail("Expected .unparseable for empty string, got \(result)")
        }
    }

    func testUnparseableMissingBDID() {
        let result = identifier.identify(serialString: "CPID:8020 ECID:0000000000000005")
        if case .unparseable = result {
            // expected
        } else {
            XCTFail("Expected .unparseable for missing BDID, got \(result)")
        }
    }

    // MARK: - Load failure for missing plist

    func testLoadFailureForMissingPlist() {
        let missingURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).plist")
        let result = identifier.load(from: missingURL)
        XCTAssertFalse(result)
        XCTAssertTrue(identifier.entries.isEmpty)
    }
}
