import AppKit

final class StepIndicatorView: NSView {

    // MARK: - Step Enum

    enum Step: Int, CaseIterable {
        case waiting  = 0
        case confirm  = 1
        case executing = 2
        case done     = 3

        var title: String {
            switch self {
            case .waiting:
                return L10n.text("step.waiting", fallback: "连接")
            case .confirm:
                return L10n.text("step.confirm", fallback: "确认")
            case .executing:
                return L10n.text("step.executing", fallback: "擦除")
            case .done:
                return L10n.text("step.done", fallback: "完成")
            }
        }
    }

    // MARK: - Properties

    var currentStep: Step = .waiting {
        didSet { needsDisplay = true }
    }

    struct Layout {
        let dotCenters: [CGPoint]
        let titleRects: [CGRect]
    }

    // MARK: - Drawing Constants

    private let dotRadius: CGFloat = 6
    private let lineLength: CGFloat = 40
    private let titleFontSize: CGFloat = 10
    private let dotToTitleGap: CGFloat = 6
    private let titleHorizontalPadding: CGFloat = 4
    private let verticalPadding: CGFloat = 4

    private let completedColor = NSColor.systemGreen
    private let currentColor   = NSColor.systemBlue
    private let futureColor    = NSColor.tertiaryLabelColor

    // MARK: - Intrinsic Content Size

    override var intrinsicContentSize: NSSize {
        let totalWidth = dotGroupWidth + titleSideInset * 2
        let titleHeight = titleSizes().map(\.height).max() ?? 0
        let height = verticalPadding * 2 + dotRadius * 2 + dotToTitleGap + ceil(titleHeight)
        return NSSize(width: totalWidth, height: height)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let steps = Step.allCases
        let layout = layout(in: bounds)

        // Draw connecting lines
        for i in 0..<(steps.count - 1) {
            let from = layout.dotCenters[i]
            let to = layout.dotCenters[i + 1]
            let lineStart = CGPoint(x: from.x + dotRadius, y: from.y)
            let lineEnd = CGPoint(x: to.x - dotRadius, y: to.y)

            let stepIndex = i + 1
            let color: NSColor
            if stepIndex <= currentStep.rawValue {
                color = completedColor
            } else {
                color = futureColor
            }

            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2)
            context.move(to: lineStart)
            context.addLine(to: lineEnd)
            context.strokePath()
        }

        // Draw dots and titles
        for (i, step) in steps.enumerated() {
            let center = layout.dotCenters[i]

            // Dot color
            let dotColor: NSColor
            if step.rawValue < currentStep.rawValue {
                dotColor = completedColor
            } else if step.rawValue == currentStep.rawValue {
                dotColor = currentColor
            } else {
                dotColor = futureColor
            }

            // Draw dot
            context.setFillColor(dotColor.cgColor)
            let dotRect = CGRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                 width: dotRadius * 2, height: dotRadius * 2)
            context.fillEllipse(in: dotRect)

            // Draw title below dot
            var titleAttributes = self.titleAttributes
            titleAttributes[.foregroundColor] = dotColor
            let titleString = step.title as NSString
            titleString.draw(in: layout.titleRects[i], withAttributes: titleAttributes)
        }
    }

    func layout(in bounds: CGRect) -> Layout {
        let steps = Step.allCases
        let titleSizes = self.titleSizes()
        let titleHeight = ceil(titleSizes.map(\.height).max() ?? 0)
        let requiredHeight = dotRadius * 2 + dotToTitleGap + titleHeight
        let contentMinY = bounds.minY + max(verticalPadding, (bounds.height - requiredHeight) / 2)
        let dotCenterY = contentMinY + titleHeight + dotToTitleGap + dotRadius

        let startX = bounds.minX + (bounds.width - dotGroupWidth) / 2

        var dotCenters: [CGPoint] = []
        var titleRects: [CGRect] = []
        var currentX = startX + dotRadius

        for (index, _) in steps.enumerated() {
            let center = CGPoint(x: currentX, y: dotCenterY)
            dotCenters.append(center)

            let titleSize = titleSizes[index]
            let titleWidth = ceil(titleSize.width) + titleHorizontalPadding * 2
            titleRects.append(CGRect(
                x: center.x - titleWidth / 2,
                y: contentMinY,
                width: titleWidth,
                height: titleHeight
            ))

            if index < steps.count - 1 {
                currentX += dotRadius * 2 + lineLength
            }
        }

        return Layout(dotCenters: dotCenters, titleRects: titleRects)
    }

    private var titleAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .center

        return [
            .font: NSFont.systemFont(ofSize: titleFontSize, weight: .medium),
            .foregroundColor: currentColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func titleSizes() -> [CGSize] {
        return Step.allCases.map { step in
            let size = (step.title as NSString).size(withAttributes: titleAttributes)
            return CGSize(width: ceil(size.width), height: ceil(size.height))
        }
    }

    private var dotGroupWidth: CGFloat {
        return CGFloat(Step.allCases.count) * dotRadius * 2
            + CGFloat(Step.allCases.count - 1) * lineLength
    }

    private var titleSideInset: CGFloat {
        let widestTitle = titleSizes().map(\.width).max() ?? 0
        return (widestTitle + titleHorizontalPadding * 2) / 2
    }
}
