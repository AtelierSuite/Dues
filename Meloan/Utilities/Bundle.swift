//
//  Bundle.swift
//  Meloan
//
//  Created by シン・ジャスティン on 2023/09/23.
//

import Foundation

extension Bundle {

    func appName() -> String {
        return self.infoDictionary!["CFBundleName"] as? String ?? "Dues"
    }

    func decode<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        do {
            if let url = self.url(forResource: file, withExtension: nil),
               let data = try? Data(contentsOf: url) {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            }
        } catch {
            debugPrint(String(describing: error))
        }
        return nil
    }
}
