import SwiftUI
import CoreData

// MARK: - iPad Layouts
// Layout specifici per iPad che utilizzano l'architettura modulare

// MARK: - Split View Layout
struct IPadSplitView<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: deviceAdapter.sidebarWidth)
                .background(Color(.systemGroupedBackground))
            
            // Separator
            Divider()
                .background(Color(.separator))
            
            // Detail View
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Three Column Layout
struct IPadThreeColumnLayout<Primary: View, Secondary: View, Detail: View>: View {
    let primary: Primary
    let secondary: Secondary
    let detail: Detail
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary, @ViewBuilder detail: () -> Detail) {
        self.primary = primary()
        self.secondary = secondary()
        self.detail = detail()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Primary Column (e.g., Chat List)
            primary
                .frame(width: deviceAdapter.sidebarWidth)
                .background(Color(.systemGroupedBackground))
            
            Divider()
                .background(Color(.separator))
            
            // Secondary Column (e.g., Message List)
            secondary
                .frame(width: deviceAdapter.sidebarWidth)
                .background(Color(.systemBackground))
            
            Divider()
                .background(Color(.separator))
            
            // Detail Column (e.g., Chat View)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Adaptive Navigation Layout
struct IPadAdaptiveNavigationLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad Layout
            NavigationView {
                content
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
        } else {
            // iPhone Layout
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

// MARK: - Grid Layout
struct IPadGridLayout<Content: View>: View {
    let content: Content
    let columns: Int
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(columns: Int? = nil, @ViewBuilder content: () -> Content) {
        self.columns = columns ?? deviceAdapter.gridColumns
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: deviceAdapter.gridSpacing), count: columns), spacing: deviceAdapter.gridSpacing) {
            content
        }
        .padding(deviceAdapter.standardSpacing)
    }
}

// MARK: - Card Grid Layout
struct IPadCardGridLayout<Content: View>: View {
    let content: Content
    let columns: Int
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(columns: Int? = nil, @ViewBuilder content: () -> Content) {
        self.columns = columns ?? deviceAdapter.gridColumns
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: deviceAdapter.gridSpacing), count: columns), spacing: deviceAdapter.gridSpacing) {
                content
            }
            .padding(deviceAdapter.standardSpacing)
        }
    }
}

// MARK: - Adaptive List Layout
struct IPadAdaptiveListLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: List con sidebar
            List {
                content
            }
            .listStyle(InsetGroupedListStyle())
            .frame(maxWidth: deviceAdapter.sidebarWidth)
        } else {
            // iPhone: List normale
            List {
                content
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}

// MARK: - Adaptive Detail Layout
struct IPadAdaptiveDetailLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Detail con larghezza limitata
            content
                .frame(maxWidth: deviceAdapter.detailWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // iPhone: Detail a schermo intero
            content
        }
    }
}

// MARK: - Adaptive Form Layout
struct IPadAdaptiveFormLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Form con larghezza limitata
            Form {
                content
            }
            .frame(maxWidth: deviceAdapter.detailWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // iPhone: Form normale
            Form {
                content
            }
        }
    }
}

// MARK: - Adaptive Sheet Layout
struct IPadAdaptiveSheetLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Sheet con larghezza limitata
            content
                .frame(maxWidth: deviceAdapter.detailWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // iPhone: Sheet normale
            content
        }
    }
}

// MARK: - Adaptive Tab Layout
struct IPadAdaptiveTabLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Tab con larghezza limitata
            TabView {
                content
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(maxWidth: deviceAdapter.detailWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // iPhone: Tab normale
            TabView {
                content
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

// MARK: - Adaptive Toolbar Layout
struct IPadAdaptiveToolbarLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Toolbar con larghezza limitata
            content
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        content
                    }
                }
                .frame(maxWidth: deviceAdapter.detailWidth)
        } else {
            // iPhone: Toolbar normale
            content
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        content
                    }
                }
        }
    }
}

// MARK: - Adaptive Input Layout
struct IPadAdaptiveInputLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Input con larghezza limitata
            content
                .frame(maxWidth: deviceAdapter.detailWidth)
                .frame(maxWidth: .infinity)
        } else {
            // iPhone: Input normale
            content
        }
    }
}

// MARK: - Adaptive Button Layout
struct IPadAdaptiveButtonLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Button con dimensioni adattate
            content
                .frame(height: deviceAdapter.largeButtonSize)
                .frame(maxWidth: deviceAdapter.detailWidth)
        } else {
            // iPhone: Button normale
            content
                .frame(height: deviceAdapter.standardButtonSize)
        }
    }
}

// MARK: - Adaptive Text Layout
struct IPadAdaptiveTextLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Text con font adattato
            content
                .font(.system(size: deviceAdapter.bodyFontSize))
                .frame(maxWidth: deviceAdapter.detailWidth)
        } else {
            // iPhone: Text normale
            content
                .font(.system(size: deviceAdapter.bodyFontSize))
        }
    }
}

// MARK: - Adaptive Image Layout
struct IPadAdaptiveImageLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Image con dimensioni adattate
            content
                .frame(maxWidth: deviceAdapter.detailWidth)
                .frame(maxWidth: .infinity)
        } else {
            // iPhone: Image normale
            content
        }
    }
}

// MARK: - Adaptive Spacing Layout
struct IPadAdaptiveSpacingLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Spacing adattato
            content
                .padding(deviceAdapter.largeSpacing)
        } else {
            // iPhone: Spacing normale
            content
                .padding(deviceAdapter.standardSpacing)
        }
    }
}

// MARK: - Adaptive Animation Layout
struct IPadAdaptiveAnimationLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Animazione più lenta
            content
                .animation(deviceAdapter.slowAnimation)
        } else {
            // iPhone: Animazione normale
            content
                .animation(deviceAdapter.standardAnimation)
        }
    }
}

// MARK: - Adaptive Haptic Layout
struct IPadAdaptiveHapticLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Haptic feedback adattato
            content
                .onTapGesture {
                    deviceAdapter.hapticFeedback(.light)
                }
        } else {
            // iPhone: Haptic feedback normale
            content
                .onTapGesture {
                    deviceAdapter.hapticFeedback(.medium)
                }
        }
    }
}

// MARK: - Adaptive Accessibility Layout
struct IPadAdaptiveAccessibilityLayout<Content: View>: View {
    let content: Content
    @ObservedObject private var deviceAdapter = DeviceAdapter.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if deviceAdapter.isLarge {
            // iPad: Accessibility adattata
            content
                .accessibilityLabel("iPad specific label")
                .accessibilityHint("iPad specific hint")
        } else {
            // iPhone: Accessibility normale
            content
                .accessibilityLabel("iPhone specific label")
                .accessibilityHint("iPhone specific hint")
        }
    }
} 