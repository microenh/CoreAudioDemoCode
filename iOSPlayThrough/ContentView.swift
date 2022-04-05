//
//  ContentView.swift
//  iOSPlayThrough
//
//  Created by Mark Erbaugh on 4/4/22.
//

import SwiftUI

struct ContentView: View {
    var viewController = ViewController()
    var body: some View {
        Text("iOS PlayThrough")
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
