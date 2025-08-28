import SwiftUI

// A transparent overlay that recognizes a two-finger pan without blocking one-finger scroll.
struct TwoFingerPanOverlay: UIViewRepresentable {
    typealias UIViewType = TwoFingerPanView

    var onBegan: ((CGPoint) -> Void)?
    var onChanged: ((CGPoint, CGPoint) -> Void)? // (start, current)
    var onEnded: ((CGPoint, CGPoint) -> Void)?

    func makeUIView(context: Context) -> TwoFingerPanView {
        let v = TwoFingerPanView()
        v.onBegan = onBegan
        v.onChanged = onChanged
        v.onEnded = onEnded
        return v
    }

    func updateUIView(_ uiView: TwoFingerPanView, context: Context) {
        uiView.onBegan = onBegan
        uiView.onChanged = onChanged
        uiView.onEnded = onEnded
    }
}

final class TwoFingerPanView: UIView {
    var onBegan: ((CGPoint) -> Void)?
    var onChanged: ((CGPoint, CGPoint) -> Void)?
    var onEnded: ((CGPoint, CGPoint) -> Void)?

    private var pan: UIPanGestureRecognizer!
    private var startPoint: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.minimumNumberOfTouches = 2
        recognizer.maximumNumberOfTouches = 2
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        addGestureRecognizer(recognizer)
        pan = recognizer
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let p = g.location(in: self)
        switch g.state {
        case .began:
            startPoint = p
            onBegan?(p)
        case .changed:
            onChanged?(startPoint, p)
        case .ended, .cancelled, .failed:
            onEnded?(startPoint, p)
        default: break
        }
    }
}

