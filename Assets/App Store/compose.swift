#!/usr/bin/env swift

import AppKit

// Frames the captures in Raw/iPhone/<lang>/ into App Store screenshots in iPhone/<lang>/,
// laid out after the original Keynote decks: a two-line header over a gradient, with the
// device below it running off the bottom of the canvas.

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let languages = ["en", "ja"]

/// 6.5" iPhone, as in the Keynote decks.
let canvasSize = NSSize(width: 1242, height: 2688)

func rawURL(_ name: String, language: String) -> URL {
    scriptDir.appendingPathComponent("Raw/iPhone/\(language)/\(name).png")
}

func outDir(_ language: String) -> URL {
    scriptDir.appendingPathComponent("iPhone/\(language)")
}

struct Copy {
    let header: String
    let caption: String
}

enum Layout {
    /// One device under the text.
    case single(String)
    /// Two devices, the second overlapping the lower half of the first.
    case stacked(String, String)

    var raws: [String] {
        switch self {
        case .single(let raw): [raw]
        case .stacked(let back, let front): [back, front]
        }
    }
}

struct Screenshot {
    let name: String
    let layout: Layout
    /// Captured by hand, so a missing capture is skipped rather than failed.
    var isOptional = false
    /// Keyed by language code. A language without copy is skipped.
    let copy: [String: Copy]
}

/// The app's accent color in light and dark appearances, read from the asset catalog so the
/// screenshots follow it.
func accentColors() -> (light: NSColor, dark: NSColor) {
    let url = scriptDir.appendingPathComponent("../../Meloan/Assets.xcassets/AccentColor.colorset/Contents.json")
    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let entries = json["colors"] as? [[String: Any]] else {
        fatalError("could not read the accent color at \(url.path)")
    }
    func component(_ value: Any?) -> CGFloat {
        let string = value as? String ?? ""
        if string.hasPrefix("0x"), let int = Int(string.dropFirst(2), radix: 16) {
            return CGFloat(int) / 255
        }
        return CGFloat(Double(string) ?? 0)
    }
    func color(of entry: [String: Any]) -> NSColor {
        let components = (entry["color"] as? [String: Any])?["components"] as? [String: Any] ?? [:]
        return NSColor(srgbRed: component(components["red"]), green: component(components["green"]),
                       blue: component(components["blue"]), alpha: 1)
    }
    let light = entries.first { $0["appearances"] == nil }.map(color) ?? .systemGreen
    let dark = entries.first { $0["appearances"] != nil }.map(color) ?? light
    return (light, dark)
}

/// The Keynote decks ran from a deep accent at the top to a pale tint at the bottom.
let background: NSGradient = {
    let accent = accentColors()
    func tint(_ color: NSColor, _ fraction: CGFloat) -> NSColor {
        color.blended(withFraction: fraction, of: .white)!
    }
    return NSGradient(
        colors: [accent.light, tint(accent.light, 0.12), tint(accent.dark, 0.25), tint(accent.light, 0.75)],
        atLocations: [0, 0.15, 0.5, 1],
        colorSpace: .sRGB
    )!
}()

let screenshots = [
    Screenshot(
        name: "01-widgets",
        layout: .single("01-widgets"),
        isOptional: true,
        copy: [
            "en": Copy(header: "Track Quicker", caption: "With Home Screen Widgets"),
            "ja": Copy(header: "ホーム画面ウィジェット", caption: "いつでも追跡できる")
        ]
    ),
    Screenshot(
        name: "02-receipts",
        layout: .single("02-receipts"),
        copy: [
            "en": Copy(header: "From Receipts to IOUs", caption: "Quickly Create and Manage Receipts"),
            "ja": Copy(header: "レシートからの貸し借り", caption: "より速くレシートを管理する")
        ]
    ),
    Screenshot(
        name: "03-receipt",
        layout: .single("03-receipt"),
        copy: [
            "en": Copy(header: "Keep in Touch", caption: "What’s Paid? What’s Not Paid?"),
            "ja": Copy(header: "情報を簡単にまとめる", caption: "支払ったかという質問にさようなら")
        ]
    ),
    Screenshot(
        name: "04-pdf",
        layout: .single("04-pdf"),
        copy: [
            "en": Copy(header: "Export & Share", caption: "PDF or Image, Your Choice"),
            "ja": Copy(header: "レシートの共有", caption: "PDFと画像に対応するならできる")
        ]
    ),
    Screenshot(
        name: "05-iou",
        layout: .single("05-iou"),
        copy: [
            "en": Copy(header: "Per Person IOUs", caption: "See How Much Each Person Owes"),
            "ja": Copy(header: "各人の貸し借り情報", caption: "借りたお金を回収しよう")
        ]
    ),
    Screenshot(
        name: "06-search",
        layout: .stacked("06-search-people", "06-search-items"),
        copy: [
            "en": Copy(header: "Easily Find", caption: "People, Receipts, Items"),
            "ja": Copy(header: "簡単に検索する", caption: "貸し借り先、レシート、商品など")
        ]
    ),
    Screenshot(
        name: "07-more",
        layout: .single("07-more"),
        copy: [
            "en": Copy(header: "Customize", caption: "Make Dues Yours"),
            "ja": Copy(header: "カスタマイズ", caption: "自分の好みに")
        ]
    )
]

// MARK: - Text

/// One line of text at the largest size up to `size` that fits `maxWidth`, in San Francisco,
/// which falls back to Hiragino Sans for Japanese.
struct Line {
    let text: String
    let attributes: [NSAttributedString.Key: Any]
    let size: NSSize

    init(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxWidth: CGFloat) {
        var fontSize = size
        var attributes: [NSAttributedString.Key: Any] = [:]
        var lineSize = NSSize.zero
        while fontSize > 10 {
            attributes = [.font: NSFont.systemFont(ofSize: fontSize, weight: weight), .foregroundColor: color]
            lineSize = (text as NSString).size(withAttributes: attributes)
            if lineSize.width <= maxWidth { break }
            fontSize -= 2
        }
        self.text = text
        self.attributes = attributes
        self.size = lineSize
        (inkTop, inkBottom) = Line.inkInsets(of: text, attributes: attributes, size: lineSize)
    }

    /// How far below the top of the line box the glyphs actually start and end.
    let inkTop: CGFloat
    let inkBottom: CGFloat

    /// Placing by font metrics leaves the text looking off, since the line box carries
    /// space above the capitals and below the baseline. So the line is rendered once and
    /// the rows its glyphs cover are measured.
    private static func inkInsets(
        of text: String, attributes: [NSAttributedString.Key: Any], size: NSSize
    ) -> (CGFloat, CGFloat) {
        let width = Int(size.width.rounded(.up))
        let height = Int(size.height.rounded(.up))
        guard width > 0, height > 0, let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return (0, size.height) }
        bitmap.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        var opaque = attributes
        opaque[.foregroundColor] = NSColor.black
        (text as NSString).draw(at: .zero, withAttributes: opaque)
        NSGraphicsContext.restoreGraphicsState()

        // Bitmap rows run top to bottom.
        let inked = (0..<height).filter { row in
            (0..<width).contains { column in (bitmap.colorAt(x: column, y: row)?.alphaComponent ?? 0) > 0.1 }
        }
        guard let first = inked.first, let last = inked.last else { return (0, size.height) }
        return (CGFloat(first), CGFloat(last + 1))
    }

    /// Draws the line centered across the canvas, with the top of its ink at `inkY`, measured
    /// down from the top of the canvas.
    func draw(inkY: CGFloat) {
        let top = canvasSize.height - inkY + inkTop
        (text as NSString).draw(
            at: NSPoint(x: ((canvasSize.width - size.width) / 2).rounded(), y: (top - size.height).rounded()),
            withAttributes: attributes
        )
    }
}

// MARK: - Device frame

func cgImage(of image: NSImage) -> CGImage {
    image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

/// Draws `raw` aspect-filled into `rect`.
func drawFilled(_ raw: CGImage, in rect: CGRect, context: CGContext) {
    let rawSize = CGSize(width: raw.width, height: raw.height)
    let scale = max(rect.width / rawSize.width, rect.height / rawSize.height)
    let drawSize = CGSize(width: rawSize.width * scale, height: rawSize.height * scale)
    context.draw(raw, in: CGRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    ))
}

let hardwareImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Hardware@2x.png"))!
let displayCG = cgImage(of: NSImage(contentsOf: scriptDir.appendingPathComponent("Display@2x.png"))!)
let hardwarePixel = NSSize(width: cgImage(of: hardwareImage).width, height: cgImage(of: hardwareImage).height)
let displayPixel = NSSize(width: displayCG.width, height: displayCG.height)
// The display mask sits centered within the hardware frame.
let displayOrigin = NSPoint(
    x: (hardwarePixel.width - displayPixel.width) / 2,
    y: (hardwarePixel.height - displayPixel.height) / 2
)
let deviceAspect = hardwarePixel.width / hardwarePixel.height

/// The raw capture clipped by the display mask, on a hardware-sized canvas.
func maskedScreen(raw: NSImage) -> NSImage {
    let image = NSImage(size: hardwarePixel)
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    let displayRect = CGRect(origin: displayOrigin, size: displayPixel)
    context.clip(to: displayRect, mask: displayCG)
    drawFilled(cgImage(of: raw), in: displayRect, context: context)
    image.unlockFocus()
    return image
}

/// Draws the device `width` wide and centered, with its top `top` down from the top of the canvas.
func drawDevice(raw: NSImage, width: CGFloat, top: CGFloat) {
    let height = width / deviceAspect
    let rect = NSRect(
        x: ((canvasSize.width - width) / 2).rounded(),
        y: (canvasSize.height - top - height).rounded(),
        width: width,
        height: height
    )
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    hardwareImage.draw(in: rect)
    NSGraphicsContext.current?.restoreGraphicsState()
    maskedScreen(raw: raw).draw(in: rect)
}

// MARK: - Composition

enum Result {
    case written
    case skipped
    case failed
}

// swiftlint:disable:next function_body_length
func compose(_ shot: Screenshot, language: String) -> Result {
    guard let copy = shot.copy[language] else { return .skipped }
    var raws: [NSImage] = []
    for name in shot.layout.raws {
        let url = rawURL(name, language: language)
        guard let raw = NSImage(contentsOf: url) else {
            if shot.isOptional {
                print("skipped \(shot.name) (\(language)): no capture at Raw/iPhone/\(language)/\(name).png")
                return .skipped
            }
            print("missing raw capture: \(url.path)")
            return .failed
        }
        raws.append(raw)
    }

    let image = NSImage(size: canvasSize)
    image.lockFocus()

    // AppKit's origin is bottom-left, so the gradient is drawn downwards to start at the top.
    background.draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    // Placed as in the Keynote decks, measured down from the top of the canvas.
    let textWidth = canvasSize.width - 96
    let header = Line(copy.header, size: 132, weight: .bold, color: .white, maxWidth: textWidth)
    let caption = Line(copy.caption, size: 64, weight: .bold, color: .white, maxWidth: textWidth)
    header.draw(inkY: 182)
    caption.draw(inkY: 182 + (header.inkBottom - header.inkTop) + 24)

    switch shot.layout {
    case .single:
        drawDevice(raw: raws[0], width: 1166, top: 510)
    case .stacked:
        drawDevice(raw: raws[0], width: 1040, top: 550)
        drawDevice(raw: raws[1], width: 1166, top: 1340)
    }

    image.unlockFocus()

    // Rasterize at exactly the canvas size in pixels.
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width), pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return .failed }
    bitmap.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { return .failed }
    try? FileManager.default.createDirectory(at: outDir(language), withIntermediateDirectories: true)
    let outURL = outDir(language).appendingPathComponent("\(shot.name).png")
    do {
        try png.write(to: outURL)
        print("wrote iPhone/\(language)/\(shot.name).png")
        return .written
    } catch {
        print("failed to write \(outURL.path): \(error)")
        return .failed
    }
}

var allSucceeded = true
for language in languages {
    for shot in screenshots where compose(shot, language: language) == .failed {
        allSucceeded = false
    }
}
exit(allSucceeded ? 0 : 1)
