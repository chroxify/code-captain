//
//  Code_CaptainApp.swift
//  Code Captain
//
//  Created by Christo Todorov on 17.07.25.
//

import SwiftUI

@main
struct CodeCaptainApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(UnifiedCompactWindowToolbarStyle(showsTitle: false))
    }
}
