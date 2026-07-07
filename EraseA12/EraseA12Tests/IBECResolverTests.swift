import XCTest
@testable import EraseA12

final class IBECResolverTests: XCTestCase {

    var bundleDir: URL!
    var userDir: URL!
    var resolver: IBECResolver!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IBECResolverTests-\(UUID().uuidString)")

        bundleDir = tempDir.appendingPathComponent("bundle")
        userDir = tempDir.appendingPathComponent("user")

        try? FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        resolver = IBECResolver(bundleDirOverride: bundleDir, userDirOverride: userDir)
    }

    override func tearDown() {
        if let bundleDir = bundleDir {
            let root = bundleDir.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: root)
        }
        resolver = nil
        bundleDir = nil
        userDir = nil
        super.tearDown()
    }

    // MARK: - Finds file in bundle dir

    func testFindsFileInBundleDir() {
        let filename = IBECResolver.ibecFilename(codename: "d331")
        let fileURL = bundleDir.appendingPathComponent(filename)
        try? Data().write(to: fileURL)

        let result = resolver.resolve(codename: "d331")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lastPathComponent, filename)
    }

    // MARK: - User override takes priority over bundle

    func testUserOverrideTakesPriority() {
        let filename = IBECResolver.ibecFilename(codename: "d331")

        // Write to both locations
        let bundleFile = bundleDir.appendingPathComponent(filename)
        let userFile = userDir.appendingPathComponent(filename)
        try? Data("bundle".utf8).write(to: bundleFile)
        try? Data("user".utf8).write(to: userFile)

        let result = resolver.resolve(codename: "d331")
        XCTAssertNotNil(result)
        // Should resolve to user dir, not bundle dir
        XCTAssertEqual(result?.deletingLastPathComponent(), userDir)
    }

    // MARK: - Returns nil when not found

    func testReturnsNilWhenNotFound() {
        let result = resolver.resolve(codename: "nonexistent")
        XCTAssertNil(result)
    }

    // MARK: - hasIBEC true/false

    func testHasIBECReturnsTrue() {
        let filename = IBECResolver.ibecFilename(codename: "n104")
        let fileURL = bundleDir.appendingPathComponent(filename)
        try? Data().write(to: fileURL)

        XCTAssertTrue(resolver.hasIBEC(codename: "n104"))
    }

    func testHasIBECReturnsFalse() {
        XCTAssertFalse(resolver.hasIBEC(codename: "nonexistent"))
    }

    // MARK: - ibecFilename format

    func testIbecFilenameFormat() {
        XCTAssertEqual(IBECResolver.ibecFilename(codename: "d331"), "iBEC.d331.RELEASE.patched")
        XCTAssertEqual(IBECResolver.ibecFilename(codename: "n104"), "iBEC.n104.RELEASE.patched")
        XCTAssertEqual(IBECResolver.ibecFilename(codename: "ipad11b"), "iBEC.ipad11b.RELEASE.patched")
    }
}
