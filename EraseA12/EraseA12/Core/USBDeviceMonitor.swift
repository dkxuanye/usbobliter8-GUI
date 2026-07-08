import Foundation
import IOKit
import IOKit.usb

protocol USBDeviceMonitorDelegate: AnyObject {
    func dfuDeviceAppeared(serialString: String)
    func dfuDeviceDisappeared()
}

final class USBDeviceMonitor {

    // MARK: - Properties

    weak var delegate: USBDeviceMonitorDelegate?

    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private var debounceTimer: Timer?

    // Apple VID and DFU PID
    private let appleVendorID = 0x05AC
    private let dfuProductID  = 0x1227

    // MARK: - Start / Stop

    func start() {
        guard notificationPort == nil else { return }

        notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
        guard let port = notificationPort else { return }

        // Add the notification port to the current run loop
        let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

        let matchingDict = createMatchingDictionary()

        // Self pointer for callbacks
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // First-match notification (device appeared)
        let matchResult = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchingDict,
            deviceAppearedCallback,
            selfPtr,
            &matchedIterator
        )
        if matchResult == kIOReturnSuccess {
            // Drain existing matches immediately
            drainIterator(matchedIterator, appeared: true)
        }

        // Terminated notification (device disappeared)
        let termResult = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matchingDict,
            deviceDisappearedCallback,
            selfPtr,
            &terminatedIterator
        )
        if termResult == kIOReturnSuccess {
            // Drain existing terminations immediately
            drainIterator(terminatedIterator, appeared: false)
        }
    }

    func stop() {
        if let timer = debounceTimer {
            timer.invalidate()
            debounceTimer = nil
        }

        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }
        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
            terminatedIterator = 0
        }
        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
    }

    deinit {
        stop()
    }

    // MARK: - Matching Dictionary

    private func createMatchingDictionary() -> NSMutableDictionary {
        let matchingDict = NSMutableDictionary()
        matchingDict[kIOUSBDeviceClassName] = kIOUSBDeviceClassName

        // Set VID and PID
        let idVendor  = kUSBVendorID as String
        let idProduct = kUSBProductID as String
        matchingDict[idVendor]  = NSNumber(value: appleVendorID)
        matchingDict[idProduct] = NSNumber(value: dfuProductID)

        return matchingDict
    }

    // MARK: - Drain Iterator

    private func drainIterator(_ iterator: io_iterator_t, appeared: Bool) {
        var service: io_object_t
        repeat {
            service = IOIteratorNext(iterator)
            if service != 0 {
                if appeared {
                    if let serial = readSerialString(from: service) {
                        scheduleDebouncedAppear(serialString: serial)
                    }
                } else {
                    scheduleDebouncedDisappear()
                }
                IOObjectRelease(service)
            }
        } while service != 0
    }

    // MARK: - Serial String Reading

    private func readSerialString(from service: io_object_t) -> String? {
        var serialString: String?

        let properties = IORegistryEntryCreateCFProperty(
            service,
            "USB Serial Number" as CFString,
            kCFAllocatorDefault,
            0
        )
        if let properties = properties {
            let value = properties.takeUnretainedValue()
            if CFGetTypeID(value) == CFStringGetTypeID() {
                serialString = (value as! String)
            }
        }

        return serialString
    }

    // MARK: - Debounce

    private func scheduleDebouncedAppear(serialString: String) {
        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.2,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.dfuDeviceAppeared(serialString: serialString)
            }
        }
    }

    private func scheduleDebouncedDisappear() {
        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.2,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.dfuDeviceDisappeared()
            }
        }
    }

    // MARK: - C Callbacks

    private let deviceAppearedCallback: IOServiceMatchingCallback = { (refCon, iterator) in
        guard let refCon = refCon else { return }
        let monitor = Unmanaged<USBDeviceMonitor>.fromOpaque(refCon).takeUnretainedValue()

        var iterator = iterator
        var service: io_object_t
        repeat {
            service = IOIteratorNext(iterator)
            if service != 0 {
                if let serial = monitor.readSerialString(from: service) {
                    monitor.scheduleDebouncedAppear(serialString: serial)
                }
                IOObjectRelease(service)
            }
        } while service != 0
    }

    private let deviceDisappearedCallback: IOServiceMatchingCallback = { (refCon, iterator) in
        guard let refCon = refCon else { return }
        let monitor = Unmanaged<USBDeviceMonitor>.fromOpaque(refCon).takeUnretainedValue()

        var iterator = iterator
        var service: io_object_t
        repeat {
            service = IOIteratorNext(iterator)
            if service != 0 {
                monitor.scheduleDebouncedDisappear()
                IOObjectRelease(service)
            }
        } while service != 0
    }
}
