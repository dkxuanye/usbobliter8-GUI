import XCTest
import AppKit
@testable import EraseA12

final class StepIndicatorViewTests: XCTestCase {

    func testStepTitlesUseChineseText() {
        XCTAssertEqual(StepIndicatorView.Step.waiting.title, "连接")
        XCTAssertEqual(StepIndicatorView.Step.confirm.title, "确认")
        XCTAssertEqual(StepIndicatorView.Step.executing.title, "擦除")
        XCTAssertEqual(StepIndicatorView.Step.done.title, "完成")
    }

    func testWaitingScreenUsesChineseText() {
        let viewController = WaitingStepViewController()

        _ = viewController.view

        let labels = Self.labelTexts(in: viewController.view)
        XCTAssertTrue(labels.contains("等待设备"))
        XCTAssertTrue(labels.contains("请使用 usbliter8 将设备进入 PWND DFU 模式"))
        XCTAssertFalse(labels.contains("Waiting for Device"))
    }

    func testErrorDescriptionsUseChineseText() {
        XCTAssertEqual(
            ObliterationError.noDevice.description,
            "未检测到 DFU 设备，请连接已进入 PWND DFU 模式的设备。"
        )
    }

    func testConfirmScreenUsesChineseText() {
        let viewController = ConfirmStepViewController()
        _ = viewController.view

        viewController.configure(
            deviceName: "测试设备",
            cpid: "8020",
            bdid: 10,
            isPWND: true,
            ibecCodename: "d321",
            canErase: true
        )

        let texts = Self.displayTexts(in: viewController.view)
        XCTAssertTrue(texts.contains("⚠️ 此操作将擦除设备上的所有数据，且不可恢复。"))
        XCTAssertTrue(texts.contains("擦除设备"))
        XCTAssertTrue(texts.contains("取消"))
        XCTAssertTrue(texts.contains("✓ 已 PWND"))
    }

    func testExecutingScreenUsesChineseText() {
        let viewController = ExecutingStepViewController()
        _ = viewController.view

        viewController.updatePhase(.uploading)

        let texts = Self.displayTexts(in: viewController.view)
        XCTAssertTrue(texts.contains("正在上传 iBEC…"))
        XCTAssertTrue(texts.contains("请勿断开设备连接"))
    }

    func testDoneScreensUseChineseText() {
        let viewController = DoneStepViewController()
        _ = viewController.view

        viewController.configureSuccess()
        var texts = Self.displayTexts(in: viewController.view)
        XCTAssertTrue(texts.contains("擦除完成"))
        XCTAssertTrue(texts.contains("设备将开始抹掉所有内容和设置。"))
        XCTAssertTrue(texts.contains("擦除另一台设备"))

        viewController.configureFailure(error: .noDevice)
        texts = Self.displayTexts(in: viewController.view)
        XCTAssertTrue(texts.contains("擦除失败"))
        XCTAssertTrue(texts.contains("重试"))
        XCTAssertTrue(texts.contains("未检测到 DFU 设备，请连接已进入 PWND DFU 模式的设备。"))
    }

    func testAboutWindowShowsCopyrightAndDeveloperCredits() {
        let information = AboutInformation(
            appName: "EraseA12",
            version: "1.2.3",
            build: "45"
        )
        let controller = AboutWindowController(information: information)

        let texts = Self.displayTexts(in: controller.window!.contentView!)
        XCTAssertTrue(texts.contains("EraseA12"))
        XCTAssertTrue(texts.contains("版本 1.2.3（45）"))
        XCTAssertTrue(texts.contains("原项目作者：overcast302"))
        XCTAssertTrue(texts.contains("由 玄烨品果开发"))
        XCTAssertTrue(texts.contains("www.dkxuanye.cn"))
        XCTAssertTrue(texts.contains("Copyright © 2026 overcast302"))
        XCTAssertTrue(texts.contains("MIT License"))
    }

    func testAboutWindowUsesFixedHTTPSLinks() {
        XCTAssertEqual(
            AboutWindowController.originalProjectURL.absoluteString,
            "https://github.com/overcast302/usbobliter8"
        )
        XCTAssertEqual(
            AboutWindowController.developerWebsiteURL.absoluteString,
            "https://www.dkxuanye.cn"
        )
    }

    func testAboutInformationReadsBundleMetadata() {
        let information = AboutInformation(infoDictionary: [
            "CFBundleName": "TestErase",
            "CFBundleShortVersionString": "2.3.4",
            "CFBundleVersion": "56"
        ])

        XCTAssertEqual(information.appName, "TestErase")
        XCTAssertEqual(information.version, "2.3.4")
        XCTAssertEqual(information.build, "56")
    }

    func testApplicationMenuContainsAboutItem() {
        let delegate = AppDelegate()
        let menu = delegate.makeMainMenu()
        let appMenu = menu.items.first?.submenu

        XCTAssertNotNil(appMenu?.items.first { $0.title == "关于 EraseA12" })
    }

    func testMainWindowShowsAboutButtonInTopRightCorner() {
        let controller = MainWindowController()
        let contentView = controller.window!.contentView!
        contentView.layoutSubtreeIfNeeded()

        guard let aboutButton = Self.buttons(in: contentView).first(where: { $0.title == "!" }) else {
            return XCTFail("主窗口缺少感叹号关于按钮")
        }
        guard let stepIndicator = Self.firstSubview(of: StepIndicatorView.self, in: contentView) else {
            return XCTFail("主窗口缺少步骤指示器")
        }

        XCTAssertEqual(aboutButton.accessibilityLabel(), "关于 EraseA12")
        XCTAssertEqual(aboutButton.toolTip, "关于 EraseA12")
        XCTAssertLessThanOrEqual(contentView.bounds.maxX - aboutButton.frame.maxX, 16)
        XCTAssertLessThanOrEqual(contentView.bounds.maxY - aboutButton.frame.maxY, 16)
        XCTAssertFalse(aboutButton.frame.intersects(stepIndicator.frame))
    }

    func testMainWindowAboutButtonCallsCallbackOnce() {
        let controller = MainWindowController()
        var callCount = 0
        controller.onShowAbout = { callCount += 1 }

        let contentView = controller.window!.contentView!
        guard let aboutButton = Self.buttons(in: contentView).first(where: { $0.title == "!" }) else {
            return XCTFail("主窗口缺少感叹号关于按钮")
        }

        aboutButton.performClick(nil)
        XCTAssertEqual(callCount, 1)
    }

    func testDefaultHeightKeepsStepTitlesInsideBounds() {
        let view = StepIndicatorView()
        let bounds = CGRect(origin: .zero, size: view.intrinsicContentSize)

        let layout = view.layout(in: bounds)

        XCTAssertEqual(layout.titleRects.count, StepIndicatorView.Step.allCases.count)
        for rect in layout.titleRects {
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertLessThanOrEqual(rect.maxX, bounds.maxX)
            XCTAssertGreaterThanOrEqual(rect.minY, 0)
            XCTAssertLessThanOrEqual(rect.maxY, bounds.maxY)
        }
    }

    func testTitleRectsHaveHorizontalGlyphPadding() {
        let view = StepIndicatorView()
        let bounds = CGRect(origin: .zero, size: view.intrinsicContentSize)

        let layout = view.layout(in: bounds)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium)
        ]

        for (step, rect) in zip(StepIndicatorView.Step.allCases, layout.titleRects) {
            let titleWidth = ceil((step.title as NSString).size(withAttributes: attributes).width)
            XCTAssertGreaterThanOrEqual(rect.width, titleWidth + 8)
        }
    }

    private static func labelTexts(in view: NSView) -> [String] {
        let ownText: [String]
        if let textField = view as? NSTextField, !textField.stringValue.isEmpty {
            ownText = [textField.stringValue]
        } else {
            ownText = []
        }

        return ownText + view.subviews.flatMap { labelTexts(in: $0) }
    }

    private static func displayTexts(in view: NSView) -> [String] {
        let ownText: [String]
        if let textField = view as? NSTextField, !textField.stringValue.isEmpty {
            ownText = [textField.stringValue]
        } else if let button = view as? NSButton, !button.title.isEmpty {
            ownText = [button.title]
        } else {
            ownText = []
        }

        return ownText + view.subviews.flatMap { displayTexts(in: $0) }
    }

    private static func buttons(in view: NSView) -> [NSButton] {
        let ownButton = (view as? NSButton).map { [$0] } ?? []
        return ownButton + view.subviews.flatMap { buttons(in: $0) }
    }

    private static func firstSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T {
            return match
        }
        return view.subviews.lazy.compactMap { firstSubview(of: type, in: $0) }.first
    }
}
