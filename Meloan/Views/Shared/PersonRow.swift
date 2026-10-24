import SwiftUI

struct PersonRow: View {

    var person: Person

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            Group {
                if let photo = person.photo, let image = UIImage(data: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image("Profile.Generic.Circle")
                        .resizable()
                }
            }
            .frame(width: 30.0, height: 30.0)
            .clipShape(Circle())
            Text(verbatim: person.name)
                .font(.body)
        }
    }
}
