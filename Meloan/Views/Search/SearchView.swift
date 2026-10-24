import SwiftData
import SwiftUI

struct SearchView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Query var receipts: [Receipt]
    @Query var receiptItems: [ReceiptItem]
    @Query var people: [Person]

    @AppStorage(wrappedValue: [], "SearchHistory", store: defaults) var searchHistory: [String]
    @State var searchTerm: String = ScreenshotScreen.current?.searchTerm ?? ""
    @State var isSearchPresented: Bool = !(ScreenshotScreen.current?.searchTerm.isEmpty ?? true)

    var body: some View {
        NavigationStack(path: $navigationManager.searchTabPath) {
            List {
                if searchTermTrimmed() == "" {
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
                } else {
                    if !receiptsFound().isEmpty {
                        Section {
                            ForEach(receiptsFound()) { receipt in
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
                    if !receiptItemsFound().isEmpty {
                        Section {
                            ForEach(receiptItemsFound()) { receiptItem in
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
                    if !peopleFound().isEmpty {
                        Section {
                            ForEach(peopleFound()) { person in
                                NavigationLink(value: ViewPath.personDetail(person: person)) {
                                    HStack(alignment: .center, spacing: 16.0) {
                                        Group {
                                            if let photo = person.photo, let image = UIImage(data: photo) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                            } else {
                                                Image("Profile.Generic")
                                                    .resizable()
                                            }
                                        }
                                        .frame(width: 30.0, height: 30.0)
                                        .clipShape(Circle())
                                        Text(person.name)
                                            .font(.body)
                                    }
                                }
                            }
                        } header: {
                            Text("Search.People")
                        }
                    }
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
            .overlay {
                if searchTerm.trimmingCharacters(in: .whitespaces) != "" &&
                    receiptsFound().isEmpty && receiptItemsFound().isEmpty && peopleFound().isEmpty {
                    ContentUnavailableView.search
                }
            }
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

    func searchTermTrimmed() -> String {
        return searchTerm.trimmingCharacters(in: .whitespaces)
    }

    func saveSearchTermToHistory() {
        guard !searchTermTrimmed().isEmpty else { return }
        searchHistory.removeAll(where: { $0 == searchTerm })
        searchHistory.insert(searchTerm, at: 0)
    }

    func receiptsFound() -> [Receipt] {
        return receipts
            .filter({ $0.name.lowercased().contains(searchTermTrimmed().lowercased())})
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }

    func receiptItemsFound() -> [ReceiptItem] {
        return receiptItems
            .filter({ $0.name.lowercased().contains(searchTermTrimmed().lowercased())})
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }

    func peopleFound() -> [Person] {
        return people
            .filter({ $0.id != "ME" && $0.name.lowercased().contains(searchTermTrimmed().lowercased())})
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }
}
