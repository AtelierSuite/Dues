import Foundation

/// A single purchased line item detected on a receipt.
struct ParsedReceiptItem: Equatable {
    var name: String
    var price: Double
    var quantity: Int
}

/// A tax or discount adjustment detected on a receipt.
struct ParsedAdjustment: Equatable {
    var name: String
    var price: Double
}

/// The structured result of parsing a scanned receipt's text.
struct ParsedReceipt: Equatable {
    var merchantName: String?
    var items: [ParsedReceiptItem]
    var taxes: [ParsedAdjustment]
    var discounts: [ParsedAdjustment]

    var isEmpty: Bool {
        items.isEmpty && taxes.isEmpty && discounts.isEmpty
    }
}

extension ReceiptTextParser {

    enum LineCategory {
        case item, tax, discount, subtotal, total, ignore
    }

    struct ParsedAmount {
        var value: Double
        var matchedText: String
    }

    enum Keywords {
        static let total = [
            "grand total", "total due", "amount due", "balance due", "total amount", "total",
            "totaal", "totale", "gesamt", "gesamtbetrag", "summe", "somme", "montant", "importe",
            "totalt", "yhteensa", "toplam", "te betalen", "rounded total",
            "合計", "総計", "总计", "總計", "합계", "tong", "tong cong", "jumlah", "kabuuan",
            "รวมทั้งสิ้น", "ยอดรวม", "ยอดสุทธิ"
        ]
        static let subtotal = [
            "subtotal", "sub-total", "sub total", "sous-total", "sous total", "zwischensumme",
            "subtotaal", "subtotale", "小計", "小计", "소계", "tam tinh", "jumlah kecil"
        ]
        static let tax = [
            "sales tax", "service charge", "svc chg", "svc", "service", "gratuity", "tip",
            "tax", "gst", "vat", "hst", "pst", "qst", "mwst", "tva", "iva", "btw", "moms",
            "cgst", "sgst", "igst", "utgst",
            "alv", "afa", "dph", "pvm", "pdv", "ppn", "sst", "pb1", "pajak", "cukai", "buwis",
            "thue", "vat 7", "消費税", "消费税", "税", "稅", "부가세", "세금", "ภาษี",
            "impuesto", "imposta", "impot", "steuer", "tasse"
        ]
        static let discount = [
            "discount", "coupon", "promo", "promotion", "rebate", "savings", "saved", "voucher",
            "member", "loyalty", "rabatt", "remise", "reduction", "sconto", "descuento", "korting",
            "ส่วนลด", "giam gia", "diskaun", "diskon", "割引", "할인", "折扣", "优惠", "優惠"
        ]
        static let ignore = [
            "cash", "change", "card", "visa", "mastercard", "amex", "debit", "credit",
            "tendered", "tender", "payment", "rounding", "round off", "auth", "approval",
            "ref", "reference", "terminal", "merchant", "thank you", "thank", "invoice no",
            "receipt no", "order no", "table", "server", "cashier", "qty", "points",
            "balance", "tel", "phone", "www", "http", "vat reg", "gst reg",
            // Receipt/invoice-number words (mostly European) — keeps ID lines like
            // "Rechnung Nr. 4711" from being read as a whole-number-currency item.
            "rechnung", "beleg", "bon nr", "facture", "factura", "recibo", "fattura",
            "faktura", "kvitto", "kuitti", "check no", "chk", "trans",
            "お釣り", "現金", "クレジット", "找零", "ありがとう"
        ]
        static let informational = [
            "vatable", "vatable sales", "vat exempt", "vat-exempt", "vat exempt sales",
            "zero rated", "zero-rated", "non-vat", "net of vat", "vat sales", "taxable amount"
        ]
    }
}
