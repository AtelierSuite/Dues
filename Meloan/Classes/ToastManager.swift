import SwiftUI

final class ToastManager: ObservableObject {

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let actionTitle: String
    }

    @Published var current: Toast?

    private var action: (() -> Void)?
    private var dismissTask: Task<Void, Never>?

    func show(message: String,
              actionTitle: String = NSLocalizedString("Toast.Undo", comment: ""),
              duration: Double = 4.5,
              action: @escaping () -> Void) {
        dismissTask?.cancel()
        self.action = action
        withAnimation(.snappy) {
            current = Toast(message: message, actionTitle: actionTitle)
        }
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    /// Runs the registered undo action and hides the toast.
    func performAction() {
        dismissTask?.cancel()
        let action = self.action
        dismiss()
        action?()
    }

    func dismiss() {
        withAnimation(.snappy) {
            current = nil
        }
        action = nil
    }
}
