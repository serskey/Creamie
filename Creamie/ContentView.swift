//
//  ContentView.swift
//  Creamie
//
//  Created by Siqi Xu on 7/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            DogProfileView()
                .tabItem {
                    Label("My Dogs", systemImage: "dog.fill")
                }
            
            Text("Messages")
                .tabItem {
                    Label("Messages", systemImage: "message")
                }
            
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
