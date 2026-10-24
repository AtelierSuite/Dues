import Komponents
import SwiftData
import SwiftUI
import TipKit

struct PeopleView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var toastManager: ToastManager
    @Query(sort: \Person.name) var people: [Person]

    var body: some View {
        NavigationStack(path: $navigationManager.peopleTabPath) {
            VStack(alignment: .leading, spacing: 0.0) {
                TipView(PeopleTip())
                    .padding(20.0)
                List {
                    if let mePerson = people.first(where: { $0.id == "ME" }) {
                        PersonRow(person: mePerson)
                    }
                    ForEach(people.filter({ $0.id != "ME" })) { person in
                        NavigationLink(value: ViewPath.personEditor(person: person)) {
                            PersonRow(person: person)
                        }
                        .deleteDisabled(!(person.receiptsPaid?.isEmpty ?? true) ||
                                        !(person.receiptsParticipated?.isEmpty ?? true))
                    }
                    .onDelete(perform: { indexSet in
                        // indexSet is into the filtered (non-ME) list, not `people`.
                        let others = people.filter { $0.id != "ME" }
                        deleteWithUndo(indexSet.compactMap { $0 < others.count ? others[$0] : nil })
                    })
                }
                .listStyle(.plain)
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .personCreator: PersonCreator()
                case .personEditor(let person): PersonEditor(person: person)
                default: Color.clear
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationManager.push(ViewPath.personCreator, for: .people)
                    } label: {
                        Label("Shared.Create", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("ViewTitle.People")
        }
    }

    func deleteWithUndo(_ peopleToDelete: [Person]) {
        guard !peopleToDelete.isEmpty else { return }
        let snapshots = peopleToDelete.map {
            (id: $0.id, name: $0.name, photo: $0.photo, dateAdded: $0.dateAdded)
        }
        for person in peopleToDelete {
            modelContext.delete(person)
        }
        try? modelContext.save()
        toastManager.show(message: NSLocalizedString("Toast.PersonDeleted", comment: "")) {
            for snapshot in snapshots {
                let person = Person(name: snapshot.name)
                person.id = snapshot.id
                person.photo = snapshot.photo
                person.dateAdded = snapshot.dateAdded
                modelContext.insert(person)
            }
            try? modelContext.save()
        }
    }
}
