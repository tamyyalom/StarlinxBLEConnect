//
//  TagManagerProtocol.swift
//  lynx
//
//  Created by user-new on 9/2/21.
//

import Foundation
import NordicDFU
import CoreBluetooth

protocol TagManagerProtocol:AnyObject {
    
    func didChangeStatus(state: CBPeripheralState)
    func didDisconnect()
    func readTagValue(data: Data)
    func dfuStateDidChange(state: DFUState)
    func dfuProgressDidChange(part: Int,totalParts: Int, to progress: Int)
}

