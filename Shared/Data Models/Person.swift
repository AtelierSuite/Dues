import Foundation
import SwiftData
import UIKit

@Model
final class Person {
    var id: String = UUID().uuidString
    var name: String = ""
    var photo: Data?
    @Relationship(inverse: \Receipt.personWhoPaid) var receiptsPaid: [Receipt]? = []
    @Relationship(inverse: \Receipt.peopleWhoParticipated) var receiptsParticipated: [Receipt]? = []
    @Relationship(inverse: \ReceiptItem.person) var receiptItemsOwned: [ReceiptItem]? = []
    @Relationship(inverse: \ReceiptItem.peopleWhoPaid) var receiptItemsPaid: [ReceiptItem]? = []
    var dateAdded: Date = Date.now

    init(name: String) {
        self.name = name
        self.photo = nil
    }

    init(name: String, photo: Data?) {
        self.name = name
        self.photo = Person.cropPhoto(photo: photo)
    }

    func setPhoto(photo: Data?) {
        self.photo = Person.cropPhoto(photo: photo)
    }

    func sumOwed(to personWhoPaid: Person?) -> Double {
        if let personWhoPaid = personWhoPaid {
            var sum: Double = .zero
            for receipt in receiptsParticipated ?? [] where receipt.personWhoPaid == personWhoPaid {
                sum += receipt.sumOwed(to: personWhoPaid, for: self)
            }
            return sum
        }
        return .zero
    }

    static func cropPhoto(photo data: Data?) -> Data? {
        if let data = data, let sourceImage = UIImage(data: data) {
            let shortSideLength = min(sourceImage.size.width, sourceImage.size.height)
            let xOffset = (sourceImage.size.width - shortSideLength) / 2.0
            let yOffset = (sourceImage.size.height - shortSideLength) / 2.0
            let cropRect = CGRect(x: xOffset, y: yOffset, width: shortSideLength, height: shortSideLength)
            let imageRendererFormat = sourceImage.imageRendererFormat
            imageRendererFormat.opaque = false
            guard let circleCroppedImage = UIGraphicsImageRenderer(size: cropRect.size,
                                                                   format: imageRendererFormat).image(actions: { _ in
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: cropRect.size)).addClip()
                sourceImage.draw(in: CGRect(origin: CGPoint(x: -xOffset, y: -yOffset), size: sourceImage.size))
            }).cgImage else { return nil }
            let length = 144 * 3
            // CGContext can reject unusual bitmap formats from arbitrary photo-library
            // images — return nil (no photo) instead of crashing.
            guard let colorSpace = circleCroppedImage.colorSpace,
                  let context = CGContext(data: nil, width: length, height: length, bitsPerComponent: 8,
                                          bytesPerRow: length * circleCroppedImage.bitsPerPixel / 8,
                                          space: colorSpace,
                                          bitmapInfo: circleCroppedImage.bitmapInfo.rawValue) else { return nil }
            context.interpolationQuality = .high
            context.draw(circleCroppedImage, in: CGRect(origin: CGPoint.zero,
                                                        size: CGSize(width: length, height: length)))
            return context.makeImage().flatMap { UIImage(cgImage: $0) }?.pngData()
        }
        return nil
    }
}
