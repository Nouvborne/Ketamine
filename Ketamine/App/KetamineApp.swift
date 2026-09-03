// xcode: set sdk=iOS

import SwiftUI

@main
struct KetamineApp: App {
    @StateObject private var store = GestaltStore()
    @AppStorage("accentColor") private var accentColor = AppAccent.blue.rawValue
    @AppStorage("customColor") private var customColor: Double = 0
    @AppStorage("useCustomColor") private var useCustomColor = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(useCustomColor
                      ? Color(hue: customColor, saturation: 0.75, brightness: 0.9)
                      : (AppAccent(rawValue: accentColor)?.color ?? .blue))
        }
    }
}
