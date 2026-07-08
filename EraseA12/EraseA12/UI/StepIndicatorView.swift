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
                return NSLocalizedString("Waiting", comment: "Step indicator: waiting step title")
            case .confirm:
                return NSLocalizedString("Confirm", comment: "Step indicator: confirm step title")
            case .executing:
                return NSLocalizedString("Executing", comment: "Step indicator: executing step title")
            case .done:
                return NSLocalizedString("Done", comment: "Step indicator: done step title")
            }
        }
    }

    // MARK: - Properties

    var currentStep: Step = .waiting {
        didSet { needsDisplay = true }
    }

    // MARK: - Drawing Constants

    private let dotRadius: CGFloat = 6
    private let lineLength: CGFloat = 40
    private let titleFontSize: CGFloat = 10

    private let completedColor = NSColor.systemGreen
    private let currentColor   = NSColor.systemBlue
    private let futureColor    = NSColor.tertiaryLabelColor

    // MARK: - Intrinsic Content Size

    override var intrinsicContentSize: NSSize {
        let totalWidth = CGFloat(Step.allCases.count) * dotRadius * 2
            + CGFloat(Step.allCases.count - 1) * lineLength
        let titleHeight: CGFloat = 16
        let dotToTitleGap: CGFloat = 6
        return NSSize(width: totalWidth, height: dotRadius * 2 + dotToTitleGap + titleHeight)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let steps = Step.allCases
        let totalWidth = intrinsicContentSize.width
        let startX = (bounds.width - totalWidth) / 2
        let dotCenterY = bounds.height - dotRadius - 16 // leave room for title below

        // Calculate dot center X positions
        var dotCenters: [CGPoint] = []
        var currentX = startX + dotRadius
        for i in 0..<steps.count {
            dotCenters.append(CGPoint(x: currentX, y: dotCenterY))
            if i < steps.count - 1 {
                currentX += lineLength
            }
        }

        // Draw connecting lines
        for i in 0..<(steps.count - 1) {
            let from = dotCenters[i]
            let to = dotCenters[i + 1]
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
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .center

        for (i, step) in steps.enumerated() {
            let center = dotCenters[i]

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
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: titleFontSize, weight: .medium),
                .foregroundColor: dotColor,
                .paragraphStyle: paragraphStyle
            ]

            let titleString = step.title as NSString
            let titleSize = titleString.size(withAttributes: titleAttributes)
            let titleX = center.x - titleSize.width / 2
            let titleY = center.y - dotRadius - 6 - titleSize.height

            titleString.draw(at: NSPoint(x: titleX, y: titleY), withAttributes: titleAttributes)
        }
    }
}
