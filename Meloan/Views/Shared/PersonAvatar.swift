import SwiftUI
import UIKit

/// A circular profile photo for a person, or the shared placeholder when there's no person.
/// The size scales with Dynamic Type unless `scalesWithText` is false.
struct PersonAvatar: View {

    var person: Person?
    var placeholder: String
    var scalesWithText: Bool
    private var baseSize: CGFloat
    @ScaledMetric private var scaledSize: CGFloat

    init(person: Person?, size: CGFloat, placeholder: String = "Profile.Generic", scalesWithText: Bool = true) {
        self.person = person
        self.placeholder = placeholder
        self.scalesWithText = scalesWithText
        self.baseSize = size
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Group {
            if let person {
                if let image = PersonPhotoCache.shared.image(for: person) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(placeholder)
                        .resizable()
                }
            } else {
                Image("Profile.Shared")
                    .resizable()
            }
        }
        .frame(width: scalesWithText ? scaledSize : baseSize,
               height: scalesWithText ? scaledSize : baseSize)
        .clipShape(Circle())
    }
}

/// Keeps decoded profile photos around so views don't decode them again on every render.
final class PersonPhotoCache {

    static let shared = PersonPhotoCache()

    private final class Entry {
        let data: Data
        let image: UIImage

        init(data: Data, image: UIImage) {
            self.data = data
            self.image = image
        }
    }

    private let cache = NSCache<NSString, Entry>()

    func image(for person: Person) -> UIImage? {
        guard let data = person.photo else { return nil }
        let key = person.id as NSString
        // Comparing the data catches photos that changed, here or through sync.
        if let entry = cache.object(forKey: key), entry.data == data {
            return entry.image
        }
        guard let image = UIImage(data: data) else { return nil }
        let decodedImage = image.preparingForDisplay() ?? image
        cache.setObject(Entry(data: data, image: decodedImage), forKey: key, cost: data.count)
        return decodedImage
    }
}
