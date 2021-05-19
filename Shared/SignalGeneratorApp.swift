//
//  SignalGeneratorApp.swift
//  Shared
//
//  Created by Morten Bertz on 2021/05/19.
//

import SwiftUI

@main
struct SignalGeneratorApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView()
            #else
            NavigationView(content: {
                ContentView()
                    .onChange(of: scenePhase, perform: { value in
                    }).navigationBarTitleDisplayMode(.inline)
            })
            #endif
            
        }
    }
}
