//
//  ServerHandler.swift
//  GyroMouse
//
//  Created by Matteo Riva on 07/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

//let ServerDiscoveredServicesDidChangeNotification = "ServerDiscoveredServicesDidChangeNotification"
let ServerDidConnectNotification = Notification.Name("ServerDidConnectNotification")
let ServerDidDisconnectNotification = Notification.Name("ServerDidDisconnectNotification")

protocol ServerHandlerDelegate: class {
    func serverDidReceivePacket(_ packet: GyroPacket)
}

class ServerHandler: NSObject, NetServiceDelegate, GCDAsyncSocketDelegate {
    
    weak var delegate: ServerHandlerDelegate?
    
    private var service: NetService?
    private var socket: GCDAsyncSocket?
    
    private let buildNumber: Int = {
        let infoDictionary = Bundle.main.infoDictionary!
        let build = infoDictionary[String(kCFBundleVersionKey)] as! String
        return Int(build)!
    }()
    
    deinit {
        delegate = nil
        
        socket?.setDelegate(nil, delegateQueue: nil)
        socket = nil
        
        service?.delegate = nil
        service = nil
    }
    
    //MARK: - Privates
    
    private func sendNotificationWithName(_ name: Notification.Name, userInfo: [String : Any]?) {
        let center = NotificationCenter.default
        let notif = Notification(name: name, object: self, userInfo: userInfo)
        center.post(notif)
    }
    
    private func parseHeader(_ data: Data) -> UInt64 {
        var headerLength: UInt64 = 0
        memcpy(&headerLength, (data as NSData).bytes, MemoryLayout<UInt64>.size)
        return headerLength
    }
    
    private func parseBody(_ data: Data) {
        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        let packet = unarchiver.decodeObject(forKey: "packet") as! GyroPacket
        unarchiver.finishDecoding()
        
        if packet.minimumVersion <= buildNumber {
            delegate?.serverDidReceivePacket(packet)
        } else {
            endConnection()
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "vers_incomp".localized
            alert.informativeText = "incomp_message".localized
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    //MARK: - Publics
    
    func endConnection() {
        socket?.disconnect()
    }
    
    func startBroadcast() {
        // Initialize GCDAsyncSocket
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        
        // Start Listening for Incoming Connections
        do {
            try socket!.accept(onPort: 0)
            service = NetService(domain: "local.", type: "_gyroserver._tcp.", name: "", port: Int32(socket!.localPort))
            service!.delegate = self
            service!.publish()
        } catch let error as NSError {
            print("Unable to create socket. Error \(error) with user info \(error.userInfo).", terminator: "\n")
        }
    }
    
    func endBroadcast() {
        socket?.setDelegate(nil, delegateQueue: nil)
        socket = nil
        
        service?.delegate = nil
        service = nil
    }
    
    //MARK: - NSNetServiceDelegate
    
    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour Service Published: domain(\(sender.domain)) type(\(sender.type)) name(\(sender.name)) port(\(sender.port))", terminator: "\n")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Failed to Publish Service: domain(\(sender.domain)) type(\(sender.type)) name(\(sender.name)) port(\(sender.port))", terminator: "\n")
    }
    
    //MARK: - GCDAsyncSocketDelegate
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Accepted New Socket from \(newSocket.connectedHost):\(newSocket.connectedPort)", "\n")
        
        socket = newSocket
        
        // Read Data from Socket
        newSocket.readData(toLength: UInt(MemoryLayout<UInt64>.size), withTimeout: -1.0, tag: 0)
        
        let notif = NSUserNotification()
        notif.title = "connected".localized
        notif.informativeText = "connect_with".localized + ":\(socket!.connectedHost) " + "completed".localized
        notif.deliveryDate = Date()
        NSUserNotificationCenter.default.scheduleNotification(notif)
        NotificationCenter.default.post(name: ServerDidConnectNotification, object: self)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if socket == sock {
            if err != nil {
                print("Socket did disconnect with error \(err)", terminator: "\n")
            } else {
                print("Socket did disconnect", terminator: "\n")
            }
            
            let notif = NSUserNotification()
            notif.title = "disconnected".localized
            notif.informativeText = "conn_terminated".localized
            notif.deliveryDate = Date()
            NSUserNotificationCenter.default.scheduleNotification(notif)
            
            NotificationCenter.default.post(name: ServerDidDisconnectNotification, object: self)
            
            endBroadcast()
            startBroadcast()
            
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if tag == 0 {
            let bodyLength = parseHeader(data)
            socket?.readData(toLength: UInt(bodyLength), withTimeout: -1, tag: 1)
        } else if tag == 1 {
            parseBody(data)
            socket?.readData(toLength: UInt(MemoryLayout<UInt64>.size), withTimeout: -1, tag: 0)
        }
    }
    
}
