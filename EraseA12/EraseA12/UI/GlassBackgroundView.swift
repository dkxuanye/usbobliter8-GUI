import AppKit

final class GlassBackgroundView: NSView {

    // MARK: - Configurable Properties

    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow {
        didSet { updateAppearance() }
    }

    var material: NSVisualEffectView.Material = .hudWindow {
        didSet { updateAppearance() }
    }

    var state: NSVisualEffectView.State = .followsWindowActiveState {
        didSet { updateAppearance() }
    }

    // MARK: - Private

    private var effectView: NSVisualEffectView?

    private let cornerRadius: CGFloat = 12

    // MARK: - Version Check

    private var isMacOS12OrLater: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion > 12 || (version.majorVersion == 12 && version.minorVersion >= 0)
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true

        if isMacOS12OrLater {
            let visualEffect = NSVisualEffectView()
            visualEffect.wantsLayer = true
            visualEffect.blendingMode = blendingMode
            visualEffect.material = material
            visualEffect.state = state
            visualEffect.layer?.cornerRadius = cornerRadius
            visualEffect.layer?.masksToBounds = true
            visualEffect.translatesAutoresizingMaskIntoConstraints = false

            addSubview(visualEffect)
            NSLayoutConstraint.activate([
                visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
                visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
                visualEffect.topAnchor.constraint(equalTo: topAnchor),
                visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            effectView = visualEffect
        } else {
            // macOS 10.15–11: solid dark background with rounded corners
            layer?.backgroundColor = NSColor(white: 0.12, alpha: 1.0).cgColor
            layer?.cornerRadius = cornerRadius
            layer?.masksToBounds = true
        }
    }

    // MARK: - Appearance Update

    private func updateAppearance() {
        guard let effectView = effectView else { return }
        effectView.blendingMode = blendingMode
        effectView.material = material
        effectView.state = state
    }
}
