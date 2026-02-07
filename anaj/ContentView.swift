#if os(macOS)
import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        LiquidContainerView {
            DashboardView()
        }
    }
}

#Preview {
    ContentView()
}
#endif
