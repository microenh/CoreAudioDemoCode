//
//  ContentView.swift
//  iOSBackgroundingTone
//
//  Created by Mark Erbaugh on 4/3/22.
//

import SwiftUI

struct ContentView: View {
    var viewController = ViewController()
    var body: some View {
        Text("Hello, world!")
            .padding()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewController.applicationWillEnterForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewController.applicationDidEnterBackground()
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
