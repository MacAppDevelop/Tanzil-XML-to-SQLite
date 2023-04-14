//
//  ContentView.swift
//  Tanzil XML to SQLite
//
//  Created by  No one on 4/14/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var converter = Converter()
    
    @State private var tableName: String = "ayaDBTable"
    @State private var surahColumnName: String = "surah_number"
    @State private var ayaColumnName: String = "aya_number"
    @State private var textColumnName: String = "text"
    
    var body: some View {
        VStack {
            switch converter.status {
            case .fileNotSelected:
                selectFileView()
            case .fileSelected:
                confirmConvertingFileView()
            case .converting:
                isConvertingView()
            case .completed:
                conversionCompletedView()
            case .saved:
                savedView()
            }
        }
        .padding()
        .alert(converter.errorMessage, isPresented: $converter.showError) {
            Button("OK"){}
        }
    }
    
    @ViewBuilder
    func selectFileView() -> some View {
        Button("Select Tanzil.net's Quran Text XML File") {
            converter.selectXMLFile()
        }
        
        Link("Link to Tanzil (remember to select XML in \"Output file format\")", destination: URL(string: "https://tanzil.net/download/")!)
            .padding(.top)
            .font(.footnote)
    }
    
    @ViewBuilder
    func confirmConvertingFileView() -> some View {
        if let fileName = converter.xmlURL?.lastPathComponent {
            Text("Selected File: \(fileName)")
        }
        
        HStack {
            Button("Convert to SQLite import file") {
                converter.convertSelectedFile()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel", role: .cancel) {
                converter.unsetSelectedFile()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    func isConvertingView() -> some View {
        Text("Converting, please wait...")
        ProgressView()
    }
    
    @ViewBuilder
    func conversionCompletedView() -> some View {
        Text("Completed! Total Ayats:").bold()
        
        Text("Without Bismillah: \(converter.tempAyatsCount)")
        Text("With Bismillah: \(converter.ayats.count)")
        
        Divider()
        
        ScrollView {
            Text("Preview:")
            LazyVStack {
                ForEach(converter.ayats) { aya in
                    Text("\(aya.surah_number) - \(aya.aya_number) - \(aya.text)")
                }
            }
            .textSelection(.enabled)
            .font(.footnote)
        }
        
        Divider()
        
        Form {
            TextField("Table Name: ", text: $tableName)
            TextField("Surah Number Column Name: ", text: $surahColumnName)
            TextField("Aya Number Column Name: ", text: $ayaColumnName)
            TextField("Text Column Name: ", text: $textColumnName)
            
            Button("Save as SQLite with Create Table and Insert") {
                converter.saveContentToDirectory(saveMode: .createTableInsert,tableName: tableName, surahNumberColumnName: surahColumnName, ayaNumberColumnName: ayaColumnName, textColumnName: textColumnName)
            }
        
            Button("Save as SQLite Update Existing Table (adds Column)") {
                converter.saveContentToDirectory(saveMode: .addColumnUpdateExistingTable,tableName: tableName, surahNumberColumnName: surahColumnName, ayaNumberColumnName: ayaColumnName, textColumnName: textColumnName)
            }
        }
    }
    
    @ViewBuilder
    func savedView() -> some View {
        Text("Filed saved!")
        
        Button("Try with another XML file") {
            converter.unsetSelectedFile()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
