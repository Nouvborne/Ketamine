import SwiftUI

struct SiriAISetupView: View {
    @EnvironmentObject private var store: GestaltStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Warning brutaliste
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.appError)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sys_Warning // Beta")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.appError)
                            .textCase(.uppercase)
                            .tracking(2)
                        Text("Experimental injection. May cause system instability or kernel panics. Proceed with caution.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.appError.opacity(0.7))
                            .lineSpacing(4)
                    }
                }
                .padding(16)
                .background(Color.appError.opacity(0.05))
                .border(Color.appError, width: 1)
                .overlay(Rectangle().frame(width: 4).foregroundColor(.appError), alignment: .leading)
                
                // Carte d'injection tech
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inject Apple Intelligence")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.appText)
                        .textCase(.uppercase)
                        .tracking(2)
                    
                    Text("Overrides REGION_US flags. Spoofs product, hardware & CPU identifiers to bypass native eligibility checks.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.appMuted)
                        .lineSpacing(4)
                        .padding(.bottom, 16)
                    
                    Button(action: {
                        Task { try? await store.applyAIRegion() }
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Execute Injection")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appAccent)
                        .foregroundColor(.black)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 15)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .techBorder(isActive: true)
                .overlay(
                    // Motif d'angle décoratif (bg-app-accent/5 rounded-bl-full)
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.05))
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous).offset(x: 32, y: -32))
                    , alignment: .topRight
                )
            }
            .padding(24)
        }
        .background(Color.appBg)
    }
}
