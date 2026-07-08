import Foundation

final class IBECResolver {

    // MARK: - Statics

    static let userOverrideDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/EraseA12/boot")
    }()

    static func ibecFilename(codename: String) -> String {
        return "iBEC.\(codename).RELEASE.patched"
    }

    // MARK: - Properties

    private let bundle: Bundle
    private let bundleDirOverride: URL?
    private let _testUserOverrideDir: URL?

    private var effectiveUserOverrideDir: URL {
        return _testUserOverrideDir ?? IBECResolver.userOverrideDir
    }

    private var effectiveBundleBootDir: URL {
        if let override = bundleDirOverride {
            return override
        }
        // Xcode flattens resource directories — iBEC files end up directly in Resources/
        // Check Resources/boot/ first (correct structure), then fall back to Resources/ (flattened)
        let bootSubdir = bundle.resourceURL?.appendingPathComponent("boot")
        if let bootDir = bootSubdir, FileManager.default.fileExists(atPath: bootDir.path) {
            return bootDir
        }
        return bundle.resourceURL ?? bundle.bundleURL
    }

    // MARK: - Init

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.bundleDirOverride = nil
        self._testUserOverrideDir = nil
    }

    /// Designated initializer for testing with directory overrides.
    init(bundleDirOverride: URL?, userDirOverride: URL? = nil) {
        self.bundle = .main
        self.bundleDirOverride = bundleDirOverride
        self._testUserOverrideDir = userDirOverride
    }

    // MARK: - Resolution

    func resolve(codename: String) -> URL? {
        let filename = IBECResolver.ibecFilename(codename: codename)

        // Priority 1: user override directory
        let userFile = effectiveUserOverrideDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: userFile.path) {
            return userFile
        }

        // Priority 2: app bundle Resources/boot/
        let bundleFile = effectiveBundleBootDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: bundleFile.path) {
            return bundleFile
        }

        return nil
    }

    func hasIBEC(codename: String) -> Bool {
        return resolve(codename: codename) != nil
    }
}
