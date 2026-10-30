import SwiftUI

struct PersonRow: View {

    var person: Person

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            PersonAvatar(person: person, size: 30.0, placeholder: "Profile.Generic.Circle")
            Text(verbatim: person.name)
                .font(.body)
        }
    }
}
