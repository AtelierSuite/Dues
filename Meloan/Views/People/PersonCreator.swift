import Komponents
import PhotosUI
import SwiftUI

struct PersonCreator: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State var name: String = ""
    @State var selectedPhoto: Data?
    @State var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Group {
                            if let selectedPhoto = selectedPhoto,
                               let image = UIImage(data: selectedPhoto) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image("Profile.Generic")
                                    .resizable()
                            }
                        }
                        .frame(width: 144, height: 144)
                        .clipShape(Circle())
                    }
                                 .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section {
                TextField("Person.Name", text: $name)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .center, spacing: 0.0) {
                Button {
                    let newPerson = Person(name: name, photo: selectedPhoto)
                    modelContext.insert(newPerson)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    LargeButtonLabel(iconName: "plus.circle.fill", text: "Shared.Create")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .disabled(name == "")
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 99))
                .frame(minHeight: 56.0)
                .padding([.leading, .trailing, .bottom], 16.0)
            }
        }
        .navigationTitle("People.Create.Title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, _ in
            Task {
                if let selectedPhotoItem = selectedPhotoItem,
                    let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                    selectedPhoto = data
                }
            }
        }
    }
}
