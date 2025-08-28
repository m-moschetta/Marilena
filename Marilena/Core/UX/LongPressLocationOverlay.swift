import SwiftUI

// Transparent overlay that reports single-finger long-press location.
struct LongPressLocationOverlay: UIViewRepresentable {
    typealias UIViewType = LongPressView

    var minimumPressDuration: TimeInterval = 0.35
    var onEnded: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> LongPressView {
        let v = LongPressView()
        v.minimumPressDuration = minimumPressDuration
        v.onEnded = onEnded
        return v
    }

    func updateUIView(_ uiView: LongPressView, context: Context) {
        uiView.minimumPressDuration = minimumPressDuration
        uiView.onEnded = onEnded
    }
}

final class LongPressView: UIView {
    var minimumPressDuration: TimeInterval = 0.35 { didSet { recognizer.minimumPressDuration = minimumPressDuration } }
    var onEnded: ((CGPoint) -> Void)?

    private lazy var recognizer: UILongPressGestureRecognizer = {
        let r = UILongPressGestureRecognizer(target: self, action: #selector(handle(_:)))
        r.minimumPressDuration = minimumPressDuration
        r.numberOfTouchesRequired = 1
        r.cancelsTouchesInView = false
        r.delaysTouchesBegan = false
        r.delaysTouchesEnded = false
        return r
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addGestureRecognizer(recognizer)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handle(_ g: UILongPressGestureRecognizer) {
        if g.state == .ended {
            let p = g.location(in: self)
            onEnded?(p)
        }
    }
}

