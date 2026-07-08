import Foundation

final class LibirecoveryBridge {

    // MARK: - Error

    enum Error: Swift.Error, CustomStringConvertible {
        case noDevice
        case unableToConnect
        case usbUpload
        case usbStatus
        case usbInterface
        case usbConfiguration
        case pipe
        case timeout
        case unsupported
        case unknown(irecv_error_t)
        case fileNotFound
        case invalidInput
        case outOfMemory

        init(code: irecv_error_t) {
            switch code {
            case IRECV_E_NO_DEVICE:         self = .noDevice
            case IRECV_E_UNABLE_TO_CONNECT: self = .unableToConnect
            case IRECV_E_USB_UPLOAD:        self = .usbUpload
            case IRECV_E_USB_STATUS:        self = .usbStatus
            case IRECV_E_USB_INTERFACE:     self = .usbInterface
            case IRECV_E_USB_CONFIGURATION: self = .usbConfiguration
            case IRECV_E_PIPE:              self = .pipe
            case IRECV_E_TIMEOUT:           self = .timeout
            case IRECV_E_UNSUPPORTED:       self = .unsupported
            case IRECV_E_FILE_NOT_FOUND:    self = .fileNotFound
            case IRECV_E_INVALID_INPUT:     self = .invalidInput
            case IRECV_E_OUT_OF_MEMORY:     self = .outOfMemory
            default:                        self = .unknown(code)
            }
        }

        var description: String {
            switch self {
            case .noDevice:         return "No device found"
            case .unableToConnect:  return "Unable to connect to device"
            case .usbUpload:        return "USB upload error"
            case .usbStatus:        return "USB status error"
            case .usbInterface:     return "USB interface error"
            case .usbConfiguration: return "USB configuration error"
            case .pipe:             return "Pipe error"
            case .timeout:          return "Operation timed out"
            case .unsupported:      return "Unsupported operation"
            case .unknown(let c):   return "Unknown libirecovery error (\(c))"
            case .fileNotFound:     return "File not found"
            case .invalidInput:     return "Invalid input"
            case .outOfMemory:      return "Out of memory"
            }
        }
    }

    // MARK: - Device Event

    enum DeviceEventType {
        case added
        case removed
    }

    struct DeviceEvent {
        let type: DeviceEventType
        let mode: Int32
    }

    // MARK: - Properties

    private var client: irecv_client_t?
    private var eventContext: irecv_device_event_context_t?

    // MARK: - Init / Deinit

    deinit {
        if let ctx = eventContext {
            irecv_device_event_unsubscribe(ctx)
            eventContext = nil
        }
        disconnect()
    }

    // MARK: - Connection

    func connect(ecid: UInt64 = 0) throws {
        disconnect()

        var newClient: irecv_client_t?
        let result = irecv_open_with_ecid_and_attempts(&newClient, ecid, 10)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
        client = newClient
    }

    func disconnect() {
        if let c = client {
            irecv_close(c)
            client = nil
        }
    }

    // MARK: - Device Info

    func readSerialString() -> String? {
        guard let c = client else { return nil }
        let info = irecv_get_device_info(c)
        guard let serial = info?.pointee.serial_string else { return nil }
        return String(cString: serial)
    }

    func getMode() -> Int32 {
        guard let c = client else { return -1 }
        var mode: Int32 = 0
        let result = irecv_get_mode(c, &mode)
        return result == IRECV_E_SUCCESS ? mode : -1
    }

    // MARK: - I/O

    func sendFile(at path: String) throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_send_file(c, path, 0)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    func sendBuffer(_ buffer: UnsafeMutablePointer<UInt8>, length: Int, options: UInt32 = 0) throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_send_buffer(c, buffer, UInt(length), options)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    // MARK: - Commands

    func sendCommand(_ command: String) throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_send_command(c, command)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    func setenv(_ variable: String, _ value: String) throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_setenv(c, variable, value)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    func saveenv() throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_saveenv(c)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    func reboot() throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_reboot(c)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    // MARK: - Reconnect / Transfer

    @discardableResult
    func reconnect(initialPause: Int32 = 0) -> Bool {
        guard let c = client else { return false }
        let newClient = irecv_reconnect(c, initialPause)
        if newClient != nil {
            client = newClient
            return true
        }
        return false
    }

    func resetCounters() throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_reset_counters(c)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    func finishTransfer() throws {
        guard let c = client else { throw Error.noDevice }
        let result = irecv_finish_transfer(c)
        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
    }

    // MARK: - Device Event Subscription

    func subscribeDeviceEvents(callback: @escaping (DeviceEvent) -> Void) throws {
        // Unsubscribe from any previous subscription
        if let ctx = eventContext {
            irecv_device_event_unsubscribe(ctx)
            eventContext = nil
        }

        // Store callback in an object that we can pass through C void* context
        let wrapper = CallbackWrapper(callback: callback)
        // We must keep wrapper alive as long as the subscription is active.
        // Store it as an associated object on self via ObjC runtime.
        objc_setAssociatedObject(self, &CallbackWrapper.associatedKey, wrapper, .OBJC_ASSOCIATION_RETAIN)

        var ctx: irecv_device_event_context_t?
        let result = irecv_device_event_subscribe(&ctx, { event, userData in
            guard let event = event, let userData = userData else { return }
            let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(userData).takeUnretainedValue()
            let eventType: DeviceEventType
            switch event.pointee.type {
            case IRECV_DEVICE_ADD:
                eventType = .added
            case IRECV_DEVICE_REMOVE:
                eventType = .removed
            default:
                eventType = .removed
            }
            let deviceEvent = DeviceEvent(type: eventType, mode: Int32(event.pointee.mode.rawValue))
            wrapper.callback(deviceEvent)
        }, Unmanaged<CallbackWrapper>.passUnretained(wrapper).toOpaque())

        guard result == IRECV_E_SUCCESS else {
            throw Error(code: result)
        }
        eventContext = ctx
    }

    func unsubscribeDeviceEvents() {
        if let ctx = eventContext {
            irecv_device_event_unsubscribe(ctx)
            eventContext = nil
        }
        objc_setAssociatedObject(self, &CallbackWrapper.associatedKey, nil, .OBJC_ASSOCIATION_RETAIN)
    }
}

// MARK: - Callback Wrapper

private final class CallbackWrapper {
    static var associatedKey: UInt8 = 0
    let callback: (LibirecoveryBridge.DeviceEvent) -> Void
    init(callback: @escaping (LibirecoveryBridge.DeviceEvent) -> Void) {
        self.callback = callback
    }
}
