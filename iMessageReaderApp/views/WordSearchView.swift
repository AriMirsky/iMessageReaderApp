//
//  SettingsView.swift
//  iMessageReaderApp
//
//  Created by Ari Mirsky on 5/15/25.
//


import SwiftUI

struct WordSearchView: View {
    var body: some View {
        VStack {
            Text("Word Search")
                .font(.largeTitle)
            Text("""
                     Not implemented while I figure out a way to read at runtime. Chat says: 
            
                     Why your SwiftUI wrapper fails
                 
                 Sandboxing & Previews

                     Xcode Previews (and Catalyst apps) run in an environment where your app’s container is isolated. They won’t see /Users/you/Library/Messages/chat.db unless you explicitly copy it into your app bundle or container.

                 Early init() timing

                     SwiftUI may instantiate WordSearchView (and call init) before your user’s home-directory is mounted or before entitlements are granted.

                 Silent nil-ing of db

                     You guard-let out of every operation if db == nil, but never expose an on-screen error. It looks like “the button does nothing,” whereas in reality runQuery() just bails out.
            """)
        }
        .padding()
    }
}
