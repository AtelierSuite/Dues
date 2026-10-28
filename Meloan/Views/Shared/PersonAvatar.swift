import SwiftUI
import UIKit

struct PersonAvatar: View {

    var person: Person
    var size: CGFloat
    var placeholder: String = "Profile.Generic"

    var body: some View {
        Group {
            if let image = PersonPhotoCache.shared.image(for: person) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(placeholder)
                    .resizable()
            }
        }
        .frame(width: size, height: size)
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
