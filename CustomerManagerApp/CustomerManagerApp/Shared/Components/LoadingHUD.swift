import SwiftUI

struct LoadingHUD: View {
    var title: String = "加载中..."

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.15)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(minWidth: 116, minHeight: 92)
            .background(Color.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct LoadingHUDModifier: ViewModifier {
    let isPresented: Bool
    let title: String
    let delay: Duration

    @State private var isVisible = false
    @State private var presentationTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isVisible {
                    LoadingHUD(title: title)
                }
            }
            .animation(.easeInOut(duration: 0.16), value: isVisible)
            .onAppear {
                updateVisibility(for: isPresented)
            }
            .onChange(of: isPresented) { _, newValue in
                updateVisibility(for: newValue)
            }
            .onDisappear {
                presentationTask?.cancel()
                presentationTask = nil
            }
    }

    private func updateVisibility(for shouldShow: Bool) {
        presentationTask?.cancel()
        presentationTask = nil

        guard shouldShow else {
            isVisible = false
            return
        }

        presentationTask = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                isVisible = true
            }
        }
    }
}

extension View {
    func loadingHUD(
        _ isPresented: Bool,
        title: String = "加载中...",
        delay: Duration = .milliseconds(180)
    ) -> some View {
        modifier(LoadingHUDModifier(isPresented: isPresented, title: title, delay: delay))
    }
}
