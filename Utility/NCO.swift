//
//  NCO.swift
//  SignalGeneratorApp
//
//  Created by Mark Erbaugh on 2/28/22.
//

import Foundation

class NCOCosine {
    static let twoPi = Double.pi * 2
    
    private var phase8 = 0.0
    private var phase16 = 0.0
    private let phaseInc: Double
    
    init(frequency: Double, sampleRate: Double) {
        phaseInc = NCOCosine.twoPi * frequency / sampleRate
    }
    
    var value16: Int16 {
        let r = Int16(cos(phase16) * Double(Int16.max))
        phase16 += phaseInc
        if phase16 >= NCOCosine.twoPi {
            phase16 -= NCOCosine.twoPi
        }
        return r
    }
    
    var value8: Int8 {
        let r = Int8(cos(phase8) * Double(Int8.max))
        phase8 += phaseInc
        if phase8 >= NCOCosine.twoPi {
            phase8 -= NCOCosine.twoPi
        }
        return r
    }
}
