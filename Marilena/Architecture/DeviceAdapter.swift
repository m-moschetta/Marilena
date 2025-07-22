import SwiftUI
import UIKit

// MARK: - Device Adapter
// Gestisce l'adattamento dell'interfaccia per diversi dispositivi

class DeviceAdapter: ObservableObject {
    static let shared = DeviceAdapter()
    
    @Published var deviceType: DeviceType = .iPhone
    @Published var orientation: UIDeviceOrientation = .portrait
    @Published var screenSize: CGSize = .zero
    
    private init() {
        updateDeviceType()
        setupOrientationObserver()
    }
    
    // MARK: - Device Type Detection
    
    enum DeviceType {
        case iPhone
        case iPad
        case mac
        case unknown
    }
    
    private func updateDeviceType() {
        #if targetEnvironment(macCatalyst)
        deviceType = .mac
        #else
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            deviceType = .iPhone
        case .pad:
            deviceType = .iPad
        default:
            deviceType = .unknown
        }
        #endif
    }
    
    // MARK: - Orientation Observer
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.orientation = UIDevice.current.orientation
        }
    }
    
    // MARK: - Layout Helpers
    
    var isCompact: Bool {
        return deviceType == .iPhone || (deviceType == .iPad && orientation.isPortrait)
    }
    
    var isRegular: Bool {
        return deviceType == .iPad && orientation.isLandscape
    }
    
    var isLarge: Bool {
        return deviceType == .iPad
    }
    
    // MARK: - Spacing
    
    var standardSpacing: CGFloat {
        switch deviceType {
        case .iPhone:
            return 16
        case .iPad:
            return orientation.isPortrait ? 20 : 24
        case .mac:
            return 24
        case .unknown:
            return 16
        }
    }
    
    var largeSpacing: CGFloat {
        return standardSpacing * 1.5
    }
    
    var smallSpacing: CGFloat {
        return standardSpacing * 0.5
    }
    
    // MARK: - Font Sizes
    
    var titleFontSize: CGFloat {
        switch deviceType {
        case .iPhone:
            return 28
        case .iPad:
            return orientation.isPortrait ? 32 : 36
        case .mac:
            return 36
        case .unknown:
            return 28
        }
    }
    
    var headlineFontSize: CGFloat {
        switch deviceType {
        case .iPhone:
            return 20
        case .iPad:
            return orientation.isPortrait ? 24 : 28
        case .mac:
            return 28
        case .unknown:
            return 20
        }
    }
    
    var bodyFontSize: CGFloat {
        switch deviceType {
        case .iPhone:
            return 16
        case .iPad:
            return orientation.isPortrait ? 18 : 20
        case .mac:
            return 20
        case .unknown:
            return 16
        }
    }
    
    var captionFontSize: CGFloat {
        switch deviceType {
        case .iPhone:
            return 12
        case .iPad:
            return orientation.isPortrait ? 14 : 16
        case .mac:
            return 16
        case .unknown:
            return 12
        }
    }
    
    // MARK: - Button Sizes
    
    var standardButtonSize: CGFloat {
        switch deviceType {
        case .iPhone:
            return 44
        case .iPad:
            return orientation.isPortrait ? 48 : 52
        case .mac:
            return 52
        case .unknown:
            return 44
        }
    }
    
    var largeButtonSize: CGFloat {
        return standardButtonSize * 1.2
    }
    
    var smallButtonSize: CGFloat {
        return standardButtonSize * 0.8
    }
    
    // MARK: - Corner Radius
    
    var standardCornerRadius: CGFloat {
        switch deviceType {
        case .iPhone:
            return 12
        case .iPad:
            return orientation.isPortrait ? 16 : 20
        case .mac:
            return 20
        case .unknown:
            return 12
        }
    }
    
    var largeCornerRadius: CGFloat {
        return standardCornerRadius * 1.5
    }
    
    var smallCornerRadius: CGFloat {
        return standardCornerRadius * 0.5
    }
    
    // MARK: - Layout Configuration
    
    var maxContentWidth: CGFloat {
        switch deviceType {
        case .iPhone:
            return UIScreen.main.bounds.width - 32
        case .iPad:
            return orientation.isPortrait ? 600 : 800
        case .mac:
            return 800
        case .unknown:
            return UIScreen.main.bounds.width - 32
        }
    }
    
    var sidebarWidth: CGFloat {
        switch deviceType {
        case .iPhone:
            return 0 // No sidebar on iPhone
        case .iPad:
            return orientation.isPortrait ? 280 : 320
        case .mac:
            return 320
        case .unknown:
            return 0
        }
    }
    
    var detailWidth: CGFloat {
        switch deviceType {
        case .iPhone:
            return UIScreen.main.bounds.width
        case .iPad:
            return orientation.isPortrait ? 600 : 800
        case .mac:
            return 800
        case .unknown:
            return UIScreen.main.bounds.width
        }
    }
    
    // MARK: - Navigation Configuration
    
    var navigationBarHeight: CGFloat {
        switch deviceType {
        case .iPhone:
            return 44
        case .iPad:
            return orientation.isPortrait ? 50 : 56
        case .mac:
            return 56
        case .unknown:
            return 44
        }
    }
    
    var tabBarHeight: CGFloat {
        switch deviceType {
        case .iPhone:
            return 49
        case .iPad:
            return orientation.isPortrait ? 56 : 64
        case .mac:
            return 64
        case .unknown:
            return 49
        }
    }
    
    // MARK: - Grid Configuration
    
    var gridColumns: Int {
        switch deviceType {
        case .iPhone:
            return 1
        case .iPad:
            return orientation.isPortrait ? 2 : 3
        case .mac:
            return 3
        case .unknown:
            return 1
        }
    }
    
    var gridSpacing: CGFloat {
        return standardSpacing
    }
    
    // MARK: - List Configuration
    
    var listRowHeight: CGFloat {
        switch deviceType {
        case .iPhone:
            return 60
        case .iPad:
            return orientation.isPortrait ? 70 : 80
        case .mac:
            return 80
        case .unknown:
            return 60
        }
    }
    
    var listSectionSpacing: CGFloat {
        return standardSpacing
    }
    
    // MARK: - Card Configuration
    
    var cardPadding: EdgeInsets {
        switch deviceType {
        case .iPhone:
            return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        case .iPad:
            return orientation.isPortrait ? 
                EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20) :
                EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        case .mac:
            return EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        case .unknown:
            return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        }
    }
    
    // MARK: - Input Configuration
    
    var textFieldHeight: CGFloat {
        switch deviceType {
        case .iPhone:
            return 44
        case .iPad:
            return orientation.isPortrait ? 48 : 52
        case .mac:
            return 52
        case .unknown:
            return 44
        }
    }
    
    var textFieldPadding: EdgeInsets {
        switch deviceType {
        case .iPhone:
            return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        case .iPad:
            return orientation.isPortrait ? 
                EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18) :
                EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        case .mac:
            return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        case .unknown:
            return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        }
    }
    
    // MARK: - Animation Configuration
    
    var standardAnimation: Animation {
        return .easeInOut(duration: 0.3)
    }
    
    var fastAnimation: Animation {
        return .easeInOut(duration: 0.2)
    }
    
    var slowAnimation: Animation {
        return .easeInOut(duration: 0.5)
    }
    
    // MARK: - Haptic Feedback
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Screen Size Detection
    
    func updateScreenSize(_ size: CGSize) {
        screenSize = size
    }
    
    var isSmallScreen: Bool {
        return screenSize.width < 375
    }
    
    var isMediumScreen: Bool {
        return screenSize.width >= 375 && screenSize.width < 768
    }
    
    var isLargeScreen: Bool {
        return screenSize.width >= 768
    }
}

// MARK: - Device-Specific Extensions

extension View {
    func adaptivePadding() -> some View {
        let adapter = DeviceAdapter.shared
        return self.padding(adapter.standardSpacing)
    }
    
    func adaptiveFont(_ style: Font.TextStyle) -> some View {
        let adapter = DeviceAdapter.shared
        return self.font(style)
    }
    
    func adaptiveCornerRadius() -> some View {
        let adapter = DeviceAdapter.shared
        return self.cornerRadius(adapter.standardCornerRadius)
    }
    
    func adaptiveButton() -> some View {
        let adapter = DeviceAdapter.shared
        return self
            .frame(height: adapter.standardButtonSize)
            .cornerRadius(adapter.standardCornerRadius)
    }
    
    func adaptiveCard() -> some View {
        let adapter = DeviceAdapter.shared
        return self
            .padding(adapter.cardPadding)
            .cornerRadius(adapter.standardCornerRadius)
    }
    
    func adaptiveListRow() -> some View {
        let adapter = DeviceAdapter.shared
        return self
            .frame(height: adapter.listRowHeight)
            .padding(.horizontal, adapter.standardSpacing)
    }
    
    func adaptiveTextField() -> some View {
        let adapter = DeviceAdapter.shared
        return self
            .frame(height: adapter.textFieldHeight)
            .padding(adapter.textFieldPadding)
            .cornerRadius(adapter.smallCornerRadius)
    }
    
    func adaptiveMaxWidth() -> some View {
        let adapter = DeviceAdapter.shared
        return self.frame(maxWidth: adapter.maxContentWidth)
    }
    
    func adaptiveAnimation() -> some View {
        let adapter = DeviceAdapter.shared
        return self.animation(adapter.standardAnimation)
    }
}

// MARK: - Device-Specific Modifiers

struct AdaptivePadding: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptivePadding()
    }
}

struct AdaptiveFont: ViewModifier {
    let style: Font.TextStyle
    
    func body(content: Content) -> some View {
        content.adaptiveFont(style)
    }
}

struct AdaptiveCornerRadius: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveCornerRadius()
    }
}

struct AdaptiveButton: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveButton()
    }
}

struct AdaptiveCard: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveCard()
    }
}

struct AdaptiveListRow: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveListRow()
    }
}

struct AdaptiveTextField: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveTextField()
    }
}

struct AdaptiveMaxWidth: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveMaxWidth()
    }
}

struct AdaptiveAnimation: ViewModifier {
    func body(content: Content) -> some View {
        content.adaptiveAnimation()
    }
}

// MARK: - View Extensions

extension View {
    func adaptive() -> some View {
        self
            .modifier(AdaptivePadding())
            .modifier(AdaptiveCornerRadius())
            .modifier(AdaptiveAnimation())
    }
    
    func adaptiveButton() -> some View {
        self.modifier(AdaptiveButton())
    }
    
    func adaptiveCard() -> some View {
        self.modifier(AdaptiveCard())
    }
    
    func adaptiveListRow() -> some View {
        self.modifier(AdaptiveListRow())
    }
    
    func adaptiveTextField() -> some View {
        self.modifier(AdaptiveTextField())
    }
    
    func adaptiveMaxWidth() -> some View {
        self.modifier(AdaptiveMaxWidth())
    }
} 