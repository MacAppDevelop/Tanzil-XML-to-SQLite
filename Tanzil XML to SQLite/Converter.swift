//
//  Converter.swift
//  Tanzil XML to SQLite
//
//  Created by No one on 4/14/23.
//

import SwiftUI
import UniformTypeIdentifiers

class Converter: NSObject, XMLParserDelegate, ObservableObject {
    @Published private(set) var status: ConversionStatus = .fileNotSelected
    
    @Published private(set) var xmlURL: URL? = nil
    private var xmlData: Data? = nil
    
    private var surah_number: Int = 0
    private var tempAyats: [Aya] = []
    @Published private(set) var tempAyatsCount: Int = 0
    
    @Published private(set) var ayats: [Aya] = []
    
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    func convertSelectedFile() {
        guard let data = xmlData else {
            triggerError("File content wasn't set correctly!")
            return
        }
        
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        
        DispatchQueue.global(qos: .userInitiated).async {
            xmlParser.parse()
        }
    }
    
    func selectXMLFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { result in
            if result == NSApplication.ModalResponse.OK {
                if let fileURL = panel.urls.first, let fileContent = try? String(contentsOf: fileURL) {
                    self.xmlURL = fileURL
                    self.xmlData = Data(fileContent.utf8)
                    self.status = .fileSelected
                } else {
                    self.status = .fileNotSelected
                    self.triggerError("Failed to read selected XML file's content")
                }
            }
        }
    }
    
    func unsetSelectedFile() {
        xmlURL = nil
        xmlData = nil
        tempAyats = []
        tempAyatsCount = 0
        ayats = []
        
        status = .fileNotSelected
    }
    
    private func triggerError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Parser Delegation Methods
extension Converter {
    func parserDidStartDocument(_ parser: XMLParser) {
        DispatchQueue.main.async {
            self.status = .converting
        }
    }
    
    private func addBismillahAsAya0ToAllSurahsExceptFatihaAndTawbah() {
        let bismillah = "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ"
        for i in 2...114 {
            if i == 9 { // No Bismillah in at-Tawbah
                continue
            }
            
            ayats.append(Aya(surah_number: i, aya_number: 0, text: bismillah))
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        // Check and complete
        if tempAyats.count == 6236 {
            DispatchQueue.main.async {
                self.tempAyatsCount = self.tempAyats.count
                self.ayats = self.tempAyats
                self.addBismillahAsAya0ToAllSurahsExceptFatihaAndTawbah()
                self.ayats.sortAyats()
                self.status = .completed
            }
        } else {
            DispatchQueue.main.async {
                self.status = .fileSelected
                self.triggerError("Total Ayats count is \(self.tempAyatsCount), not 6236! Something went wrong...")
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        DispatchQueue.main.async {
            self.triggerError("Parse error occurred when trying to parse XML file: \(parseError.localizedDescription)")
            self.status = .fileSelected
        }
    }
    
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        DispatchQueue.main.async {
            self.triggerError("Validation error occurred when trying to parse XML file: \(validationError.localizedDescription)")
            self.status = .fileSelected
        }
    }
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if elementName == "sura" {
            for (key, val) in attributeDict {
                if key == "index", let surah_id = Int(val) {
                    surah_number = surah_id
                }
            }
        } else {
            var aya_number: Int? = nil
            var aya_text: String? = nil
            
            for (key, val) in attributeDict {
                if key == "index", let aya_id_val = Int(val) {
                    aya_number = aya_id_val
                }
                
                if key == "text" {
                    aya_text = String(val)
                }
            }
            
            if let aya_number, let aya_text {
                tempAyats.append(Aya(surah_number: surah_number, aya_number: aya_number, text: aya_text))
            }
        }
    }
}

// MARK: - Generate SQLite Import File
extension Converter {
    func generateSQLiteCreateTableInsert(tableName: String, surahNumberColumnName: String, ayaNumberColumnName: String, textColumnName: String) -> String {
        var sqlite: String = ""
        
        sqlite.newLine()
        
        sqlite.addTanzilCopyrightAndModification()
        
        sqlite.newLine(2)
        
        sqlite.append("PRAGMA encoding=\"UTF-8\";")
        sqlite.newLine(2)
        
        sqlite.append("""
        CREATE TABLE `\(tableName)` (
          `\(surahNumberColumnName)` int(3) NOT NULL,
          `\(ayaNumberColumnName)` int(3) NOT NULL,
          `\(textColumnName)` text NOT NULL,
          PRIMARY KEY  (`\(surahNumberColumnName)`, `\(ayaNumberColumnName)`)
        );
        """)
        sqlite.newLine(3)
        
        var surahNumber = 0
        
        let insertIntoString = "INSERT INTO `\(tableName)` (`\(surahNumberColumnName)`, `\(ayaNumberColumnName)`, `\(textColumnName)`) VALUES"
        
        for aya in ayats {
            if aya.surah_number != surahNumber {
                if surahNumber != 0 {
                    sqlite.append(";")
                    sqlite.newLine(2)
                }
                
                surahNumber = aya.surah_number
                sqlite.append("-- Surah \(surahNumber)")
                sqlite.newLine()
                
                sqlite.append(insertIntoString)
                sqlite.newLine()
            } else {
                sqlite.append(",")
                sqlite.newLine()
            }
            
            sqlite.append("(\(aya.surah_number), \(aya.aya_number), '\(aya.text)')")
            
            if aya.surah_number == 114 && aya.aya_number == 6 {
                sqlite.append(";")
                sqlite.newLine(2)
            }
        }
        
        return sqlite
    }
    
    func generateSQLiteAddColumnUpdateExistingTable(tableName: String, surahNumberColumnName: String, ayaNumberColumnName: String, textColumnName: String) -> String {
        var sqlite: String = ""
        
        sqlite.newLine()
        
        sqlite.addTanzilCopyrightAndModification()
        
        sqlite.newLine(2)
        
        sqlite.append("PRAGMA encoding=\"UTF-8\";")
        sqlite.newLine(2)
        
        // Add column to table
        sqlite.append("ALTER TABLE \(tableName) ADD `\(textColumnName)` text NOT NULL DEFAULT '';")
        sqlite.newLine(2)
        
        var surahNumber = 0
        
        for aya in ayats {
            if aya.surah_number != surahNumber {
                surahNumber = aya.surah_number
                sqlite.newLine(2)
                sqlite.append("-- Surah \(surahNumber)")
                sqlite.newLine()
            }
            
            let updateQuery = "UPDATE `\(tableName)` SET `\(textColumnName)` = '\(aya.text)' WHERE `\(surahNumberColumnName)` = \(aya.surah_number) AND `\(ayaNumberColumnName)` = \(aya.aya_number);"
            
            sqlite.append(updateQuery)
            sqlite.newLine()
        }
        
        return sqlite
    }
    
    func saveContentToDirectory(saveMode: SQLiteFileSaveMode, tableName: String, surahNumberColumnName: String, ayaNumberColumnName: String, textColumnName: String) {
        let panel = NSOpenPanel()
        panel.title = "Select a Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.begin { (result) in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                guard let url = panel.url else {
                    #if DEBUG
                    print("Failed to get URL from panel.")
                    #endif
                    return
                }
                
                let fileName = "\(tableName)-\(saveMode.rawValue)-sqlite.sql"
                var fileContent = ""
                
                if saveMode == .addColumnUpdateExistingTable {
                    fileContent = self.generateSQLiteAddColumnUpdateExistingTable(tableName: tableName, surahNumberColumnName: surahNumberColumnName, ayaNumberColumnName: ayaNumberColumnName, textColumnName: textColumnName)
                } else {
                    fileContent = self.generateSQLiteCreateTableInsert(tableName: tableName, surahNumberColumnName: surahNumberColumnName, ayaNumberColumnName: ayaNumberColumnName, textColumnName: textColumnName)
                }
                let fileURL = url.appendingPathComponent(fileName)
                
                do {
                    try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
                    self.status = .saved
                } catch {
                    self.triggerError("Failed to save content to directory: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension String {
    mutating func newLine(_ count: Int = 1) {
        for _ in 1...count {
            self.append("\n")
        }
    }
    
    mutating func addTanzilCopyrightAndModification() {
        self.append("""
--====================================================================
-- Note: This .sql file is converted from .xml files of Tanzil.net
-- In the process of conversion Bismillah is added in the beginning
-- of each Surah with aya_number 0 (except for Al-Fatiha and at-Tawbah)
--====================================================================

--====================================================================
-- PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK
--====================================================================
--
--  Tanzil Quran Text (Simple, Version 1.1)
--  Copyright (C) 2007-2023 Tanzil Project
--  License: Creative Commons Attribution 3.0
--
--  This copy of the Quran text is carefully produced, highly
--  verified and continuously monitored by a group of specialists
--  at Tanzil Project.
--
--  TERMS OF USE:
--
--  - Permission is granted to copy and distribute verbatim copies
--    of this text, but CHANGING IT IS NOT ALLOWED.
--
--  - This Quran text can be used in any website or application,
--    provided that its source (Tanzil Project) is clearly indicated,
--    and a link is made to tanzil.net to enable users to keep
--    track of changes.
--
--  - This copyright notice shall be included in all verbatim copies
--    of the text, and shall be reproduced appropriately in all files
--    derived from or containing substantial portion of this text.
--
--  Please check updates at: http://tanzil.net/updates/
--
--====================================================================

""")
    }
}

enum ConversionStatus {
    case fileNotSelected
    case fileSelected
    case converting
    case completed
    case saved
}

enum SQLiteFileSaveMode {
    case addColumnUpdateExistingTable
    case createTableInsert
    
    var rawValue: String {
        String(describing: self)
    }
}
