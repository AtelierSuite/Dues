import Komponents
import SwiftData
import SwiftUI
import UIKit

struct PeoplePicker: View {

    @Environment(\.dismiss) var dismiss
    @Query(sort: \Person.name) var people: [Person]
    var title: String
    @Binding var selection: [Person]?
    @State private var isAddingPerson: Bool = false

    var body: some View {
        List {
            if people.filter({ $0.id != "ME" }).isEmpty {
                Text("PeoplePicker.Empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            if let mePerson = people.first(where: { $0.id == "ME" }) {
                personToggleRow(mePerson)
            }
            ForEach(people.filter({ $0.id != "ME" })) { person in
                personToggleRow(person)
            }
            Button {
                isAddingPerson = true
            } label: {
                Label("PeoplePicker.AddPerson", systemImage: "person.badge.plus")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Shared.Done")
                }
            }
        }
        .sheet(isPresented: $isAddingPerson) {
            NavigationStack {
                PersonCreator()
            }
        }
        .navigationTitle(LocalizedStringKey(title))
    }

    func personToggleRow(_ person: Person) -> some View {
        Button {
            if selection?.contains(where: { $0.id == person.id }) ?? false {
                selection?.removeAll { $0.id == person.id }
            } else {
                selection?.append(person)
            }
        } label: {
            HStack {
                PersonRow(person: person)
                    .tint(.primary)
                Spacer()
                Image(systemName: "checkmark")
                    .fontWeight(.medium)
                    .opacity((selection?.contains(where: { $0.id == person.id }) ?? false) ? 1 : 0)
            }
        }
    }
}
