//
//  ViewModel.swift
//  MIDIWiFiSource
//
//  Created by Mark Erbaugh on 4/6/22.
//

import SwiftUI
import CoreMIDI
import AVFAudio

// MARK: Constants
fileprivate struct Settings {
    static let destinationName = "Mac Mini 2"
    static let destinationAddress = "192.168.12.127"
    static let destinationPort = 5004
    static let midiClientName = "MyMIDIWifi Client" as CFString
    static let midiPortName = "MyMIDIWifi Output Port" as CFString
}

// MARK: State


class ViewModel {
    
    var midiSession = MIDINetworkSession.default()
    var outport = MIDIPortRef()
    let destinationEndpoint: MIDIEndpointRef
    
    init() {
        let host = MIDINetworkHost(name: Settings.destinationName,
                                   address: Settings.destinationAddress,
                                   port: Settings.destinationPort)

        let connection = MIDINetworkConnection(host: host)
                
        midiSession.addConnection(connection)
        midiSession.isEnabled = true
        destinationEndpoint = midiSession.destinationEndpoint()
        
        var client = MIDIClientRef()
        
        checkError(MIDIClientCreate(Settings.midiClientName,
                                    nil,
                                    nil,
                                    &client),
                   "Couldn't create MIDI client")
        checkError(MIDIOutputPortCreate(client,
                                        Settings.midiPortName,
                                        &outport),
                   "Couldn't create output port")
        print ("Got output port")
    }
    
    func sendStatus(status: UInt8, data1: UInt8, data2: UInt8) {
        
        var packet = MIDIPacket()
        packet.data.0 = status
        packet.data.1 = data1
        packet.data.2 = data2
        packet.timeStamp = 0
        packet.length = 3
        
        var packetList = MIDIPacketList(numPackets: 1, packet: (packet))
        
        checkError(MIDISend(outport,
                            destinationEndpoint,
                            &packetList),
                   "Couldn't send MIDI packet list")
        
    }
    
    func sendNoteOnEvent(key: UInt8, velocity: UInt8) {
        sendStatus(status: 0x90, data1: key & 0x7f, data2: velocity & 0x7f)
    }
    
    func sendNoteOffEvent(key: UInt8, velocity: UInt8) {
        sendStatus(status: 0x80, data1: key & 0x7f, data2: velocity & 0x7f)
    }
    
    
}
