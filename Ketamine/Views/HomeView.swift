import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var category: TweakCategory? = .display
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Status industriel (remplace commandStatus)
                HStack(spacing: 16) {
                    ZStack {
                        Rectangle()
                            .fill(Color.appAccent.opacity(0.1))
                            .border(Color.appAccent, width: 1)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.appAccent.opacity(0.15), radius: 15)
                        Image(systemName: "terminal")
                            .foregroundColor(.appAccent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(store.enabledCount) Staged")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appText)
                                .textCase(.uppercase)
                                .tracking(2)
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 8, height: 8)
                        }
                        Text("SYS_OVERRIDE_ACTIVE")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.appMuted)
                    }
                    Spacer()
                }
                .padding(.bottom, 24)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.zinc800), alignment: .bottom)
                
                // Catégories (façon terminaux)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryButton(title: "ALL", isSelected: category == nil) { category = nil }
                        ForEach(TweakCategory.allCases.filter { $0 != .ai }) { item in
                            categoryButton(title: item.rawValue.uppercased(), isSelected: category == item) { category = item }
                        }
                    }
                }
                
                // Grille de configuration
                HStack {
                    Text("ACTIVE_CONFIG")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.appMuted)
                        .tracking(2)
                    Spacer()
                }
                .padding(.leading, 8)
                .overlay(Rectangle().frame(width: 2).foregroundColor(.appAccent), alignment: .leading)
                
                VStack(spacing: 0) {
                    ForEach(categoryTweaks) { tweak in
                        HStack {
                            Image(systemName: tweak.symbol)
                                .foregroundColor(.zinc800)
                                .frame(width: 24)
                            Text(tweak.title)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.appText)
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { tweak.isEnabled },
                                set: { newValue in store.setEnabled(newValue, for: tweak.id) }
                            ))
                            .toggleStyle(TechToggleStyle())
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.02))
                        .overlay(Rectangle().frame(height: 1).foregroundColor(.zinc800), alignment: .bottom)
                    }
                }
                .techBorder()
            }
            .padding(24)
        }
        .background(Color.appBg)
    }
    
    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .tracking(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .foregroundColor(isSelected ? .appAccent : .appMuted)
                .background(isSelected ? Color.appAccent.opacity(0.1) : Color.clear)
                .border(isSelected ? Color.appAccent : Color.zinc800, width: 1)
        }
        .buttonStyle(.plain)
    }
    
    private var categoryTweaks: [Tweak] {
        guard let category else { return store.tweaks.filter { $0.category != .ai } }
        return store.tweaks.filter { $0.category == category }
    }
}
