import AppIntents

struct DuesShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateReceiptIntent(),
            phrases: [
                "Create a receipt in \(.applicationName)",
                "New receipt in \(.applicationName)",
                "Split a bill with \(.applicationName)"
            ],
            shortTitle: "Create Receipt",
            systemImageName: "receipt"
        )
        AppShortcut(
            intent: AddReceiptItemIntent(),
            phrases: [
                "Add an item to \(\.$receipt) in \(.applicationName)",
                "Add an item to a receipt in \(.applicationName)"
            ],
            shortTitle: "Add Item",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: MarkReceiptItemPaidIntent(),
            phrases: [
                "Mark \(\.$item) as paid in \(.applicationName)",
                "Mark an item as paid in \(.applicationName)"
            ],
            shortTitle: "Mark Item Paid",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: MarkReceiptPaidIntent(),
            phrases: [
                "Mark \(\.$receipt) as paid in \(.applicationName)",
                "Settle a receipt in \(.applicationName)"
            ],
            shortTitle: "Mark Receipt Paid",
            systemImageName: "checkmark.seal"
        )
    }
}
