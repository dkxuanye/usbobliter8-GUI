import Foundation

enum ObliterationError: Swift.Error, CustomStringConvertible {

    case noDevice
    case notPWND
    case unsupportedDevice(cpid: String, bdid: Int)
    case ibecNotFound(codename: String)
    case uploadFailed(underlying: Swift.Error)
    case bootFailed(underlying: Swift.Error)
    case recoveryTimeout
    case commandFailed(underlying: Swift.Error)
    case deviceDisconnected
    case unknown(underlying: Swift.Error)

    var description: String {
        switch self {
        case .noDevice:
            return NSLocalizedString(
                "No device detected. Please connect your device in DFU mode.",
                comment: "Error: no device found"
            )
        case .notPWND:
            return NSLocalizedString(
                "Device is not in PWND state. The device must be jailbroken via checkra1n before proceeding.",
                comment: "Error: device not PWND"
            )
        case .unsupportedDevice(let cpid, let bdid):
            return String(format: NSLocalizedString(
                "This device (CPID:%@ BDID:%d) is not supported by EraseA12.",
                comment: "Error: unsupported device"
            ), cpid, bdid)
        case .ibecNotFound(let codename):
            return String(format: NSLocalizedString(
                "Required iBEC file for codename \"%@\" was not found. Please ensure the application resources are intact.",
                comment: "Error: iBEC file not found"
            ), codename)
        case .uploadFailed:
            return NSLocalizedString(
                "Failed to upload data to the device. Please try reconnecting the device.",
                comment: "Error: upload failed"
            )
        case .bootFailed:
            return NSLocalizedString(
                "Failed to boot the device. Please try again.",
                comment: "Error: boot failed"
            )
        case .recoveryTimeout:
            return NSLocalizedString(
                "Timed out waiting for the device to enter recovery mode. Please try again.",
                comment: "Error: recovery timeout"
            )
        case .commandFailed:
            return NSLocalizedString(
                "A command sent to the device failed. Please try again.",
                comment: "Error: command failed"
            )
        case .deviceDisconnected:
            return NSLocalizedString(
                "The device was unexpectedly disconnected. Please reconnect it.",
                comment: "Error: device disconnected"
            )
        case .unknown:
            return NSLocalizedString(
                "An unexpected error occurred. Please try again.",
                comment: "Error: unknown error"
            )
        }
    }
}
