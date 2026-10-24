import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }
}

struct ToastCapsule: View {

    let toast: ToastManager.Toast
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 14.0) {
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: onAction) {
                HStack(spacing: 4.0) {
                    Image(systemName: "arrow.uturn.backward")
                    Text(toast.actionTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20.0)
        .padding(.vertical, 13.0)
        .liquidGlassCapsule()
        .shadow(color: .black.opacity(0.18), radius: 12.0, y: 4.0)
        .padding(.horizontal, 16.0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}

struct ToastPresenter: ViewModifier {

    @EnvironmentObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = toastManager.current {
                ToastCapsule(toast: toast) {
                    toastManager.performAction()
                }
                .padding(.bottom, 60.0)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

extension View {
    /// Presents the app-wide undo toast above this view (e.g. the root tab view).
    func undoToast() -> some View {
        modifier(ToastPresenter())
    }
}
