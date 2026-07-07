import Foundation

struct DeviceEntry {
    let name: String
    let ibecCodename: String
    let cpid: String
    let bdid: Int
}

enum DeviceIdentification {
    case recognized(entry: DeviceEntry, isPWND: Bool, ecid: String)
    case unsupportedChip(cpid: String)
    case unknownBoard(cpid: String, bdid: Int)
    case unparseable
}

final class DeviceIdentifier {

    // MARK: - Supported CPIDs

    private let supportedCPIDs: Set<String> = ["0x8020", "0x8030"]

    // MARK: - Entries

    private var entries: [DeviceEntry] = []

    // MARK: - Load

    @discardableResult
    func load(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let array = plist as? [[String: Any]] else {
            return false
        }

        entries = array.compactMap { dict -> DeviceEntry? in
            guard let name = dict["name"] as? String,
                  let ibecCodename = dict["ibecCodename"] as? String,
                  let cpid = dict["cpid"] as? String,
                  let bdid = dict["bdid"] as? Int else {
                return nil
            }
            return DeviceEntry(name: name, ibecCodename: ibecCodename, cpid: cpid, bdid: bdid)
        }

        return !entries.isEmpty
    }

    // MARK: - Identify

    func identify(serialString: String?) -> DeviceIdentification {
        // Unparseable: nil or empty
        guard let serial = serialString, !serial.isEmpty else {
            return .unparseable
        }

        // Parse CPID
        guard let cpid = serialField(serial, key: "CPID") else {
            return .unparseable
        }

        // Check if chip is supported
        guard supportedCPIDs.contains(cpid) else {
            return .unsupportedChip(cpid: cpid)
        }

        // Parse BDID
        guard let bdidStr = serialField(serial, key: "BDID"),
              let bdid = Int(bdidStr, radix: 16) else {
            return .unparseable
        }

        // Parse ECID (optional for identification, but included in result)
        let ecid = serialField(serial, key: "ECID") ?? ""

        // Parse PWND
        let isPWND = serialField(serial, key: "PWND") != nil

        // Find matching entry
        if let entry = entries.first(where: { $0.cpid == cpid && $0.bdid == bdid }) {
            return .recognized(entry: entry, isPWND: isPWND, ecid: ecid)
        }

        return .unknownBoard(cpid: cpid, bdid: bdid)
    }

    // MARK: - Serial Field Parser

    /// Parses space-separated KEY:VALUE pairs from the DFU serial string.
    /// Format: "CPID:8020 BDID:0A ECID:... PWND:[...]"
    private func serialField(_ serial: String, key: String) -> String? {
        let components = serial.split(separator: " ")
        for component in components {
            let parts = component.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, String(parts[0]) == key else { continue }
            return String(parts[1])
        }
        return nil
    }
}
