import Foundation

/// Sunucudan gelen her türlü JSON değerini güvenle tutar.
/// Sayı bazen metin ("16106.00"), bazen sayı (16106) gelebilir; ikisini de okur.
enum JSONDeger: Codable, Hashable {
    case yazi(String)
    case numara(Double)
    case dogruYanlis(Bool)
    case liste([JSONDeger])
    case sozluk([String: JSONDeger])
    case yok

    init(from decoder: Decoder) throws {
        let kap = try decoder.singleValueContainer()
        if kap.decodeNil() {
            self = .yok
        } else if let b = try? kap.decode(Bool.self) {
            self = .dogruYanlis(b)
        } else if let d = try? kap.decode(Double.self) {
            self = .numara(d)
        } else if let s = try? kap.decode(String.self) {
            self = .yazi(s)
        } else if let a = try? kap.decode([JSONDeger].self) {
            self = .liste(a)
        } else if let o = try? kap.decode([String: JSONDeger].self) {
            self = .sozluk(o)
        } else {
            throw DecodingError.dataCorruptedError(in: kap, debugDescription: "Bilinmeyen JSON değeri")
        }
    }

    func encode(to encoder: Encoder) throws {
        var kap = encoder.singleValueContainer()
        switch self {
        case .yazi(let s): try kap.encode(s)
        case .numara(let d): try kap.encode(d)
        case .dogruYanlis(let b): try kap.encode(b)
        case .liste(let a): try kap.encode(a)
        case .sozluk(let o): try kap.encode(o)
        case .yok: try kap.encodeNil()
        }
    }

    /// Değerin metin hâli (sayılar da metne çevrilir).
    var metin: String? {
        switch self {
        case .yazi(let s):
            return s
        case .numara(let d):
            if d == d.rounded() && abs(d) < 1e15 {
                return String(Int64(d))
            }
            return String(d)
        case .dogruYanlis(let b):
            return b ? "1" : "0"
        default:
            return nil
        }
    }

    var tamsayi: Int? {
        switch self {
        case .numara(let d):
            return Int(d)
        case .yazi(let s):
            let t = s.trimmingCharacters(in: .whitespaces)
            if let i = Int(t) { return i }
            if let d = Double(t) { return Int(d) }
            return nil
        case .dogruYanlis(let b):
            return b ? 1 : 0
        default:
            return nil
        }
    }

    var ondalik: Double? {
        switch self {
        case .numara(let d):
            return d
        case .yazi(let s):
            return Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        default:
            return nil
        }
    }

    var mantik: Bool? {
        switch self {
        case .dogruYanlis(let b): return b
        case .numara(let d): return d != 0
        case .yazi(let s): return s == "1" || s.lowercased() == "true"
        default: return nil
        }
    }

    var nesne: [String: JSONDeger]? {
        if case .sozluk(let o) = self { return o }
        return nil
    }

    var dizi: [JSONDeger]? {
        if case .liste(let a) = self { return a }
        return nil
    }
}

/// Bir veritabanı satırı.
typealias Satir = [String: JSONDeger]

extension Dictionary where Key == String, Value == JSONDeger {
    /// Boşlukları kırpılmış metin; yoksa boş metin.
    func metin(_ anahtar: String) -> String {
        return (self[anahtar]?.metin ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Boşsa nil döner.
    func secimli(_ anahtar: String) -> String? {
        let m = metin(anahtar)
        return m.isEmpty ? nil : m
    }

    func tamsayi(_ anahtar: String) -> Int {
        return self[anahtar]?.tamsayi ?? 0
    }

    func ondalik(_ anahtar: String) -> Double? {
        return self[anahtar]?.ondalik
    }

    /// '["a","b"]' biçimindeki metni listeye çevirir; düz metinse tek maddelik liste verir.
    func liste(_ anahtar: String) -> [String] {
        guard let s = secimli(anahtar) else { return [] }
        if s.hasPrefix("["), let veri = s.data(using: .utf8),
           let dizi = try? JSONDecoder().decode([JSONDeger].self, from: veri) {
            return dizi.compactMap { deger -> String? in
                let m = (deger.metin ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return m.isEmpty ? nil : m
            }
        }
        return [s]
    }
}
