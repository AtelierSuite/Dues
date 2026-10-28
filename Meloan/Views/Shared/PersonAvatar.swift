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
                if let image = PersonPhotoCache.image(for: person) {
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

/// Decodes profile photos once and reuses them across renders.
enum PersonPhotoCache {

    private static let cache = NSCache<NSString, UIImage>()

    static func image(for person: Person) -> UIImage? {
        guard let data = person.photo else { return nil }
        // Keying on the data's hash means a changed photo is decoded again.
        let key = "\(person.id)-\(data.hashValue)" as NSString
        if let image = cache.object(forKey: key) {
            return image
        }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
