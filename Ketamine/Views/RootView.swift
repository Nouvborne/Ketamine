import SwiftUI

struct MainTabView: View {
    @State private var activeTab: Tab = .tweaks
    
    enum Tab: String, CaseIterable {
        case tweaks = "TWEAKS"
        case custom = "THEME"
        case siri = "SIRI_AI"
        case settings = "SYS_CFG"
        
        var icon: String {
            switch self {
            case .tweaks: return "terminal"
            case .custom: return "paintpalette"
            case .siri: return "cpu"
            case .settings: return "gearshape.2"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBg.ignoresSafeArea()
            
            // Scanline Background Effect
            ScanlineView()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("v2.0_BETA // KETAMINE")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.appAccent)
                        
                        Text(headerTitle)
                            .font(.system(size: 24, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundColor(.appText)
                            .tracking(2)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.zinc800).frame(width: 8, height: 8)
                        Rectangle().fill(Color.zinc800).frame(width: 8, height: 8)
                        Rectangle().fill(Color.appAccent).frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 16)
                .background(Color.appBg)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.zinc800), alignment: .bottom)
                
                // Content
                TabView(selection: $activeTab) {
                    HomeView().tag(Tab.tweaks)
                    CustomizationOfflineView().tag(Tab.custom) // Remplaçant pour THEME
                    SiriAISetupView().tag(Tab.siri)
                    SystemHubView().tag(Tab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.bottom, 60) // Espace pour la tab bar
            
            // Custom Tab Bar (Glass Panel)
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .foregroundColor(activeTab == tab ? .appAccent : .zinc800)
                            Text(tab.rawValue)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(activeTab == tab ? .appText : .zinc800)
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(activeTab == tab ? Color.white.opacity(0.05) : Color.clear)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(activeTab == tab ? .appAccent : .clear),
                            alignment: .top
                        )
                    }
                }
            }
            .background(Color.appBg.opacity(0.95))
            .overlay(Rectangle().frame(height: 1).foregroundColor(.zinc800), alignment: .top)
        }
        .ignoresSafeArea(.keyboard)
    }
    
    var headerTitle: String {
        switch activeTab {
        case .tweaks: return "Tweak_Engine"
        case .siri: return "AI_Override"
        default: return "Module_Cfg"
        }
    }
}

// Scanline Effect
struct ScanlineView: View {
    @State private var offset: CGFloat = -1000
    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(Color.appAccent.opacity(0.2))
                .frame(height: 4)
                .blur(radius: 1)
                .offset(y: offset)
                .onAppear {
                    withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                        offset = proxy.size.height + 100
                    }
                }
        }.allowsHitTesting(false)
    }
}

// Vue pour les modules hors-ligne
struct CustomizationOfflineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cone.fill")
                .font(.system(size: 32))
                .foregroundColor(.zinc800)
            Text("[ MODULE OFFLINE ]")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.zinc800)
                .tracking(2)
            Text("Access restricted")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBg)
    }
}
