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
        let osStatus = NewAUGraph(&graph)
        guard osStatus == noErr else {
            throw CAError.newGraph(osStatus)
        }
        return graph!
    }
    
    func addNode(componentType: OSType, componentSubType: OSType) throws -> AUNode{
        var cd = AudioComponentDescription(componentType: componentType,
                                           componentSubType: componentSubType)
        var node = AUNode()
        let osStatus = AUGraphAddNode(self,
                                      &cd,
                                      &node)
        guard osStatus == noErr else {
            throw CAError.addGraphNode(osStatus)
        }
        return node
    }
    
    func open() throws {
        let osStatus = AUGraphOpen(self)
        guard osStatus == noErr else {
            throw CAError.openGraph(osStatus)
        }
    }
    
    func getNodeAU(node: AUNode) throws -> AudioUnit {
        var unit: AudioUnit?
        let osStatus = AUGraphNodeInfo(self,
                                       node,
                                       nil,
                                       &unit)
        guard osStatus == noErr else {
            throw CAError.getUnit(osStatus)
        }
        return unit!
    }
    
    func connectNodes(node1: AUNode, bus1: UInt32, node2: AUNode, bus2: UInt32) throws {
        let osStatus = AUGraphConnectNodeInput(self, node1, bus1, node2, bus2)
        guard osStatus == noErr else {
            throw CAError.connectNodes(osStatus)
        }
    }
    
    func initialze() throws {
        let osStatus = AUGraphInitialize(self)
        guard osStatus == noErr else {
            throw CAError.initializeGraph(osStatus)
        }
    }
    
    func start() throws {
        let osStatus = AUGraphStart(self)
        guard osStatus == noErr else {
            throw CAError.graphStart(osStatus)
        }
    }
}
