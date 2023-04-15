//
//  Aya.swift
//  Tanzil XML to SQLite
//
//  Created by No one on 4/14/23.
//

import Foundation

struct Aya: Identifiable, Equatable {
    let surah_number: Int
    let aya_number: Int
    let text: String
    
    var id: String {
        "\(surah_number),\(aya_number)"
    }
    
    static func ==(lhs: Aya, rhs: Aya) -> Bool {
        return lhs.surah_number == rhs.surah_number && lhs.aya_number == rhs.aya_number
    }
}

extension Array where Element == Aya {
    mutating func sortAyats() {
        self.sort {
            ($0.surah_number, $0.aya_number) < ($1.surah_number, $1.aya_number)
        }
    }
}
