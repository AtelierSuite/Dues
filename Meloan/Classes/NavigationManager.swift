import Foundation

class NavigationManager: ObservableObject {

    @Published var receiptsTabPath: [ViewPath] = []
    @Published var iouTabPath: [ViewPath] = []
    @Published var peopleTabPath: [ViewPath] = []
    @Published var searchTabPath: [ViewPath] = []
    @Published var moreTabPath: [ViewPath] = []

    func popAll() {
        receiptsTabPath.removeAll()
        iouTabPath.removeAll()
        peopleTabPath.removeAll()
        searchTabPath.removeAll()
        moreTabPath.removeAll()
    }

    func popToRoot(for tab: TabType) {
        switch tab {
        case .receipts:
            receiptsTabPath.removeAll()
        case .iou:
            iouTabPath.removeAll()
        case .people:
            peopleTabPath.removeAll()
        case .search:
            searchTabPath.removeAll()
        case .more:
            moreTabPath.removeAll()
        }
    }

    func push(_ viewPath: ViewPath, for tab: TabType) {
        switch tab {
        case .receipts:
            receiptsTabPath.append(viewPath)
        case .iou:
            iouTabPath.append(viewPath)
        case .people:
            peopleTabPath.append(viewPath)
        case .search:
            searchTabPath.append(viewPath)
        case .more:
            moreTabPath.append(viewPath)
        }
    }

}
