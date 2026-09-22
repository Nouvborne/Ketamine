import SwiftUI

struct AppMark: View {
    let name: String
    let size: CGFloat
    var tint: Color = .appAccent

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
    }
}

struct SectionHeader: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.appMuted)
                .tracking(1.5)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.appAccent)
            }
        }
        .padding(.horizontal, 4)
        .overlay(Rectangle().frame(width: 2).foregroundColor(.appAccent), alignment: .leading)
        .padding(.leading, -4)
    }
}

struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isBusy = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .tint(.black)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(Color.appAccent)
        .foregroundColor(.black)
        .shadow(color: Color.appAccent.opacity(0.3), radius: 15)
        .disabled(disabled || isBusy)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

struct ProgressOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.appBg.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.appAccent)
                    .controlSize(.large)
                Text(message)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.appText)
                    .textCase(.uppercase)
                    .tracking(2)
            }
            .padding(32)
            .background(Color.appCard)
            .border(Color.zinc800, width: 1)
            .techBorder(isActive: true)
        }
        .transition(.opacity)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                Text(message)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.appAccent)
                    .textCase(.uppercase)
                    .tracking(1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.appCard)
                    .border(Color.appAccent, width: 1)
                    .shadow(color: Color.appAccent.opacity(0.2), radius: 10)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: isPresented) {
                        guard isPresented else { return }
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.snappy) { isPresented = false }
                    }
            }
        }
        .animation(.snappy, value: isPresented)
    }
}

extension View {
    /// A bottom-anchored, self-dismissing banner — for one-off "you found
    /// something" style feedback (easter eggs, unlocks) rather than errors.
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}
