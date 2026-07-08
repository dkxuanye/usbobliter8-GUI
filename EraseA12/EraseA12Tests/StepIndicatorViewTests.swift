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
}
