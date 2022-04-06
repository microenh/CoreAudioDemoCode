//
//  ContentView.swift
//  MIDIWiFiSource
//
//  Created by Mark Erbaugh on 4/6/22.
//

import SwiftUI

fileprivate struct Settings {
    static let keyWidth = CGFloat(40)
    static let keyHeight = CGFloat(120)
    static let keySpacing = CGFloat(5)
}

let whiteKeys = [
    ("C", UInt8(60), 1),
    ("D", UInt8(62), 2),
    ("E", UInt8(64), 3),
    ("F", UInt8(65), 4),
    ("G", UInt8(67), 5),
    ("A", UInt8(69), 6),
    ("B", UInt8(71), 7),
    ("C", UInt8(72), 8),
    ("D", UInt8(74), 9),
    ("E", UInt8(76), 10),
    ("F", UInt8(77), 11),
    ("G", UInt8(79), 12),
    ("A", UInt8(81), 13),
    ("B", UInt8(83), 14),
    ("C", UInt8(84), 15)
]

let blackKeys = [
    ("C#", UInt8(61), 1),
    ("D#", UInt8(63), 2),
    ("E#", UInt8(0), 3),
    ("F#", UInt8(66), 4),
    ("G#", UInt8(68), 5),
    ("A#", UInt8(70), 6),
    ("B#", UInt8(0), 7),
    ("C#", UInt8(73), 8),
    ("D#", UInt8(75), 9),
    ("E#", UInt8(0), 10),
    ("F#", UInt8(78), 11),
    ("G#", UInt8(80), 12),
    ("A#", UInt8(82), 13),
    ("B#", UInt8(0), 14)
    ]

struct ContentView: View {
    let viewModel = ViewModel()
    var body: some View {
        VStack(alignment: .leading, spacing: Settings.keySpacing) {
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: Settings.keyWidth / 2, height: Settings.keyHeight)
                ForEach(blackKeys, id: \.self.2) { (title, note, _) in
                    if note == 0 {
                        Spacer()
                            .frame(width: Settings.keyWidth, height: Settings.keyHeight)
                    } else {
                        Key(viewModel: viewModel, title: title, note: note, black: true)
                    }
                    Spacer()
                        .frame(width: Settings.keySpacing)
                }
            }
            HStack(spacing: 0) {
                ForEach(whiteKeys, id: \.self.2) { (title, note, _) in
                    Key(viewModel: viewModel, title: title, note: note, black: false)
                    Spacer()
                        .frame(width: Settings.keySpacing)
                }
            }
        }
    }
}

struct Key: View {
    var viewModel: ViewModel
    let title: String
    let note: UInt8
    let black: Bool
    var body: some View {
        Text(title)
            .onTouchDownUp { pressed in
                if pressed {
                    viewModel.sendNoteOnEvent(key: note, velocity: 0x7f)
                    // print ("\(note) on")
                } else {
                    viewModel.sendNoteOffEvent(key: note, velocity: 0x7f)
                    // print ("\(note) off")
                }
            }
            .foregroundColor(black ? .white : .black)
            .frame(width: Settings.keyWidth, height: Settings.keyHeight)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(black ? .black : .white))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black)
            )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeRight)
    }
}
