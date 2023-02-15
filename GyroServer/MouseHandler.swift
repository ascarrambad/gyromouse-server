//
//  MouseHandler.swift
//  GyroServer
//
//  Created by Matteo Riva on 07/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

import CoreGraphics
import Cocoa
import Carbon
import CoreServices

class MouseHandler: NSObject, ServerHandlerDelegate {
    
    private let server = ServerHandler()
    
    //private var pitch = 0.0
    //private var yaw = 0.0
    
    private var activeScreen: Int {
        get {
            return UserDefaults.standard.integer(forKey: "activeScreen")
        }
    }    
    private var mLoc: (x: CGFloat, y: CGFloat) = (x: 0, y: 0)
    private var isClicking = false

    override init() {
        super.init()
        resetPointerPosition(moveMouse: false)
        server.startBroadcast()
        NotificationCenter.default.addObserver(forName: ActiveScreenDidChangeNotification, object: nil, queue: OperationQueue.main) {[unowned self] (_) -> Void in
            self.resetPointerPosition(moveMouse: false)
        }
        NotificationCenter.default.addObserver(forName: ServerDidConnectNotification, object: nil, queue: OperationQueue.main) {[unowned self] (_) -> Void in
            self.resetPointerPosition(moveMouse: true)
            self.server.delegate = self
        }
        NotificationCenter.default.addObserver(forName: ServerDidDisconnectNotification, object: nil, queue: OperationQueue.main) {[unowned self] (_) -> Void in
            self.server.delegate = nil
            self.resetPointerPosition(moveMouse: false)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - Mouse movements
    
    private func computePointerMovementWithPacket(_ packet: GyroPacket) {
        //let dx = ((packet.yaw! * -1 - yaw) * (1 + abs(packet.accX!))) * packet.moveVelocity!
        //let dy = ((packet.pitch! * -1 - pitch) * (1 + abs(packet.accZ!))) * packet.moveVelocity!
        let roll = packet.roll
        let sgn: Double = roll ?? 0 < 0 ? -1 : 1
        let gate = 0.75
        let changeMovCond = roll == nil || (roll! > -gate && roll! < gate)
        
        let rotatZ = changeMovCond ? packet.rotatZ! : packet.rotatX! * -sgn
        let accZ = changeMovCond ? packet.accZ! : packet.accX!
        let rotatX = changeMovCond ? packet.rotatX! : packet.rotatZ! * sgn
        let accX = changeMovCond ? packet.accX! : packet.accZ!
        let gravZ = changeMovCond ? packet.gravZ! : packet.gravX! * sgn
        
        //print("roll: \(roll) \(sgn) cond: \(changeMovCond)\n")
        
        var dx = ((rotatZ * -1) * (1 + abs(accZ))) * packet.moveVelocity! * abs(gravZ)
        var dy = ((rotatX * -1) * (1 + abs(accX))) * packet.moveVelocity! * abs(gravZ)
        
        if packet.type == .scroll {
            dx = min(dx,1)
            dy = min(dy,1)
        }
        
        //let dxa = tan((packet.yaw * -1 - yaw)) * 700 * (1 + abs(packet.accX))
        //let dya = tan(packet.pitch * -1 - pitch) * 700 * (1 + abs(packet.accZ))
        
        movePointerTo(x: CGFloat(dx), y: CGFloat(dy), relativeToLocation: true)
        
        //pitch = packet.pitch! * -1
        //yaw = packet.yaw! * -1
    }
    
    private func movePointerTo(x: CGFloat, y: CGFloat, relativeToLocation: Bool) {
        var x = x, y = y
        
        let frame = NSScreen.screens()![activeScreen].frame
        let s = (o: frame.origin, w: frame.maxX-1, h: frame.maxY-1)
        
        if relativeToLocation {
            x += mLoc.x
            y += mLoc.y
        }
        
        //NSLog("mLoc x: %f y: %f, x: %f y: %f", mLoc.x,mLoc.y,x-mLoc.x,y-mLoc.y)
        
        //mLoc = (x: max(s.o.x,min(x, s.w)), y: max(0,min(y, s.h)))
        mLoc = (x: x, y: y)
        x = max(s.o.x,min(x, s.w))
        y = max(0,min(y, s.h))
        
        //NSLog("x: %f y: %f", x,y)

        let point = CGPoint(x: x, y: y)
        
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cgSessionEventTap)
        
        if isClicking {
            let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left)
            drag?.post(tap: .cgSessionEventTap)
        }
    }
    
    func resetPointerPosition(moveMouse: Bool) {
        let aIndex = UserDefaults.standard.integer(forKey: "activeScreen")
        let frame = NSScreen.screens()![aIndex].frame
        let x = frame.midX
        let y = frame.midY - frame.origin.y
        //NSLog("x: %f, y: %f, origin x: %f, y: %f, mid x: %f, y: %f", x,y,frame.origin.x, frame.origin.y, frame.midX, frame.midY)
        if moveMouse {
            movePointerTo(x: x, y: y, relativeToLocation: false)
        } else {
            mLoc = (x: x, y: y)
        }
    }
    
    //MARK: - Mouse actions
    
    var rollGate = 0
    
    private func scrollWithRoll(_ roll: Double, velocity: Double) {
        rollGate += 1
        if rollGate == 10 {
            CFunctions.scroll(withRoll: roll * velocity * 2)
            rollGate = 0
        }
    }

    private func clickButton(_ button: ButtonType, click: ClickType) {
        
        let mouseEvent: CGEventType
        let mouseButton: CGMouseButton
        
        if button == .left {
            mouseButton = .left
            mouseEvent = click == .down ? .leftMouseDown : .leftMouseUp
            isClicking = click == .down
        } else {
            mouseButton = .right
            mouseEvent = click == .down ? .rightMouseDown : .rightMouseUp
        }
        
        let point = CGPoint(x: mLoc.x, y: mLoc.y)
        
        let action = CGEvent(mouseEventSource: nil, mouseType: mouseEvent, mouseCursorPosition: point, mouseButton: mouseButton)
        action?.post(tap: .cgSessionEventTap)
    }
    
    //MARK: - Keyboard actions
    
    private func stringToKeyCodeWithString(_ chars: NSString) {
        for i in 0 ..< chars.length {
            if let keyArr = KeyCodeGenerator.keyCode(forChar: chars.character(at: i)) {
                let keycode = CGKeyCode(keyArr[0] as Int)
                let modif = keyArr[1] as Int
                //print("key: \(keycode) modif: \(modif)", terminator: "\n")
                
                let flag: CGEventFlags?
                
                switch modif {
                case 2: flag = .maskShift
                case 8: flag = .maskAlternate
                case 10: flag =  CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue ^ CGEventFlags.maskAlternate.rawValue)
                default: flag = nil
                }
                
                simulateKeyPressWithKeyCode(keycode, AndModifier: flag)
            }
        }
    }
    
    private func simulateKeyPressWithKeyCode(_ key: CGKeyCode, AndModifier modifier: CGEventFlags?) {
        
        let keypress = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
        keypress?.type = .keyDown
        if modifier != nil { keypress?.flags = modifier! }
        keypress?.post(tap: .cgSessionEventTap)
        
        let keypressUP = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        keypressUP?.type = .keyUp
        keypressUP?.post(tap: .cgSessionEventTap)
    }
    
    //MARK: - Shutdown actions
    
    private func shutdownWithShutdownType(_ shutType: ShutdownType) {
        
        let type: UInt32
        
        switch shutType {
        case .shutdown: type = UInt32(kAEShutDown)
        case .reboot: type = UInt32(kAERestart)
        case .logout: type = UInt32(kAEReallyLogOut)
        case .sleep: type = UInt32(kAESleep)
        }
        
        CFunctions.sendAppleEvent(toSystemProcess: type)
    }
    
    //MARK: - ServerHandlerDelegate
    
    func serverDidReceivePacket(_ packet: GyroPacket) {
        switch packet.type {
        case .scroll: scrollWithRoll(packet.roll!, velocity: packet.scrollVelocity!)
            fallthrough
        case .movement: computePointerMovementWithPacket(packet)
        case .click: clickButton(packet.button!, click: packet.click!)
        case .keyTapped: stringToKeyCodeWithString(packet.key! as NSString)
        case .deleteBackward: simulateKeyPressWithKeyCode(CGKeyCode(kVK_Delete), AndModifier: nil)
        case .returnTapped: simulateKeyPressWithKeyCode(CGKeyCode(kVK_Return), AndModifier: nil)
        case .resetPointerPosition: resetPointerPosition(moveMouse: true)
        case .volumeUp:
            NSSound.increaseSystemVolume(by: 0.06)
            NSSound(named: "volume")?.play()
        case .volumeDown:
            NSSound.decreaseSystemVolume(by: 0.06)
            NSSound(named: "volume")?.play()
        case .shutdown: shutdownWithShutdownType(packet.shutdownType!)
        }
    }
    
}
