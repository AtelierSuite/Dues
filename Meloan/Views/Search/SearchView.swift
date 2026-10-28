import SwiftData
import SwiftUI

struct SearchView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: [], "SearchHistory", store: defaults) var searchHistory: [String]
    @State var searchTerm: String = ScreenshotScreen.current?.searchTerm ?? ""
    @State var isSearchPresented: Bool = !(ScreenshotScreen.current?.searchTerm.isEmpty ?? true)

    var body: some View {
        NavigationStack(path: $navigationManager.searchTabPath) {
            Group {
                if searchTermTrimmed().isEmpty {
                    searchHistoryList()
                } else {
                    SearchResultsView(searchTerm: searchTermTrimmed())
                }
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .receiptDetail(let receipt): ReceiptDetailView(receipt: receipt)
                case .receiptItemDetail(let receiptItem): ReceiptItemDetailView(receiptItem: receiptItem)
                case .personDetail(let person): PeopleDetailView(person: person)
                default: Color.clear
                }
            })
            .searchable(text: $searchTerm, isPresented: $isSearchPresented)
            .onSubmit(of: .search, {
                saveSearchTermToHistory()
            })
            .onChange(of: navigationManager.searchTabPath, { oldValue, newValue in
                if oldValue.count == 0 && newValue.count == 1 {
                    saveSearchTermToHistory()
                }
            })
            .navigationTitle("ViewTitle.Search")
        }
    }

    @ViewBuilder
    func searchHistoryList() -> some View {
        List {
            Section {
                ForEach(searchHistory, id: \.self) { historicalSearchTerm in
                    Button {
                        withAnimation {
                            searchTerm = historicalSearchTerm
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 16.0) {
                            Image(systemName: "magnifyingglass")
                            Text(historicalSearchTerm)
                            Spacer()
                            Image(systemName: "arrow.up.backward.circle")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .onDelete { indexSet in
                    searchHistory.remove(atOffsets: indexSet)
                }
            } header: {
                HStack(alignment: .center, spacing: 4.0) {
                    Text("Search.History")
                    Spacer()
                    Button {
                        searchHistory.removeAll()
                    } label: {
                        Text("Search.History.Clear")
                            .textCase(.none)
                    }
                }
            }
        }
    }

    func searchTermTrimmed() -> String {
        return searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveSearchTermToHistory() {
        let searchTerm = searchTermTrimmed()
        guard !searchTerm.isEmpty else { return }
        searchHistory.removeAll(where: { $0 == searchTerm })
        searchHistory.insert(searchTerm, at: 0)
    }
}

/// Matches are fetched by the store, so only the results are loaded, once per search term.
struct SearchResultsView: View {

    @Query var receipts: [Receipt]
    @Query var receiptItems: [ReceiptItem]
    @Query var people: [Person]

    init(searchTerm: String) {
        // The store's comparison ignores case and diacritics, but not character width, so
        // the half-width and full-width forms are searched for too (e.g. ｶﾚｰ and カレー).
        let term = searchTerm
        let halfwidthTerm = searchTerm.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? searchTerm
        let fullwidthTerm = searchTerm.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? searchTerm
        _receipts = Query(filter: #Predicate<Receipt> {
            $0.name.localizedStandardContains(term) ||
            $0.name.localizedStandardContains(halfwidthTerm) ||
            $0.name.localizedStandardContains(fullwidthTerm)
        }, sort: \Receipt.name)
        _receiptItems = Query(filter: #Predicate<ReceiptItem> {
            $0.name.localizedStandardContains(term) ||
            $0.name.localizedStandardContains(halfwidthTerm) ||
            $0.name.localizedStandardContains(fullwidthTerm)
        }, sort: \ReceiptItem.name)
        _people = Query(filter: #Predicate<Person> {
            $0.id != "ME" && (
                $0.name.localizedStandardContains(term) ||
                $0.name.localizedStandardContains(halfwidthTerm) ||
                $0.name.localizedStandardContains(fullwidthTerm)
            )
        }, sort: \Person.name)
    }

    var body: some View {
        List {
            if !receipts.isEmpty {
                Section {
                    ForEach(receipts) { receipt in
                        NavigationLink(value: ViewPath.receiptDetail(receipt: receipt)) {
                            Label {
                                HStack {
                                    Text(receipt.name)
                                    Spacer()
                                    Text(format(receipt.sum()))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "receipt")
                            }
                        }
                    }
                } header: {
                    Text("Search.Receipts")
                }
            }
            if !receiptItems.isEmpty {
                Section {
                    ForEach(receiptItems) { receiptItem in
                        NavigationLink(value: ViewPath.receiptItemDetail(receiptItem: receiptItem)) {
                            Label {
                                HStack {
                                    Text(receiptItem.name)
                                    Spacer()
                                    Text(format(receiptItem.price))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "cart")
                            }
                        }
                    }
                } header: {
                    Text("Search.ReceiptItems")
                }
            }
            if !people.isEmpty {
                Section {
                    ForEach(people) { person in
                        NavigationLink(value: ViewPath.personDetail(person: person)) {
                            PersonRow(person: person)
                        }
                    }
                } header: {
                    Text("Search.People")
                }
            }
        }
        .overlay {
            if receipts.isEmpty && receiptItems.isEmpty && people.isEmpty {
                ContentUnavailableView.search
            }
        }
    }
}
