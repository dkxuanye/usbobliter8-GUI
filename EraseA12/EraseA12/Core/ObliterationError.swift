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
            return L10n.text(
                "error.no_device",
                fallback: "未检测到 DFU 设备，请连接已进入 PWND DFU 模式的设备。"
            )
        case .notPWND:
            return L10n.text(
                "error.not_pwnd",
                fallback: "检测到设备但未处于 PWND 状态，请先使用 usbliter8。"
            )
        case .unsupportedDevice(let cpid, let bdid):
            return L10n.format(
                "error.unsupported_device_format",
                fallback: "不支持此设备（CPID:%@ BDID:%d）。",
                cpid,
                bdid
            )
        case .ibecNotFound(let codename):
            return L10n.format(
                "error.ibec_not_found_format",
                fallback: "未找到代号“%@”所需的 iBEC 文件，请确认应用资源完整。",
                codename
            )
        case .uploadFailed:
            return L10n.text("error.upload_failed", fallback: "上传 iBEC 失败")
        case .bootFailed:
            return L10n.text("error.boot_failed", fallback: "启动 iBEC 失败")
        case .recoveryTimeout:
            return L10n.text(
                "error.recovery_timeout",
                fallback: "等待恢复模式超时，请重新连接后重试。"
            )
        case .commandFailed:
            return L10n.text("error.command_failed", fallback: "发送擦除指令失败")
        case .deviceDisconnected:
            return L10n.text(
                "error.device_disconnected",
                fallback: "设备意外断开，请重新进入 PWND DFU 模式后重试。"
            )
        case .unknown:
            return L10n.text("error.unknown", fallback: "发生错误")
        }
    }
}
