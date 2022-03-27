//
//  AUGraph.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/26/22.
//

import AVFoundation

extension AUGraph {
    static func new() throws -> AUGraph {
        var graph: AUGraph?
        try checkOSStatus(NewAUGraph(&graph))
        return graph!
    }
    
    func addNode(componentType: OSType, componentSubType: OSType) throws -> AUNode{
        var cd = AudioComponentDescription(componentType: componentType,
                                           componentSubType: componentSubType)
        var node = AUNode()
        try checkOSStatus(AUGraphAddNode(self, &cd, &node))
        return node
    }
    
    func open() throws {
        try checkOSStatus(AUGraphOpen(self))
    }
    
    func getNodeAU(node: AUNode) throws -> AudioUnit {
        var unit: AudioUnit?
        try checkOSStatus(AUGraphNodeInfo(self, node, nil,  &unit))
        return unit!
    }
    
    func connectNodes(node1: AUNode, bus1: UInt32, node2: AUNode, bus2: UInt32) throws {
        try checkOSStatus(AUGraphConnectNodeInput(self, node1, bus1, node2, bus2))
    }
    
    func initialze() throws {
        try checkOSStatus(AUGraphInitialize(self))
    }
    
    func start() throws {
        try checkOSStatus(AUGraphStart(self))
        
    }
}
