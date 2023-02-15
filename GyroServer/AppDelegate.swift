//
//  AppDelegate.swift
//  GyroServer
//
//  Created by Matteo Riva on 07/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

import Cocoa
import CoreServices
import Sparkle
import Fabric
import Crashlytics

let ActiveScreenDidChangeNotification = Notification.Name("ActiveScreenDidChangeNotification")
let yellow = NSColor(red: 255.0/255.0, green: 223.0/255.0, blue: 17.0/255.0, alpha: 1)
let blue = NSColor(red: 41.0/255.0, green: 95.0/255.0, blue: 196.0/255.0, alpha: 1)

extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var mouseHandler: MouseHandler!
    
    let statusBarItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    let screenMenu = NSMenu()
    let window = FirstBootWindowController(windowNibName: "FirstBootWindowController")
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        Fabric.with([Crashlytics.self()])
        
        if !UserDefaults.standard.bool(forKey: "firstBoot") {
            window.completion = {[unowned self] in
                self.setupApp()
            }
            window.showWindow(self)
        } else {
            setupApp()
        }
    }
    
    func setupApp() {
        if SUUpdater.shared().automaticallyChecksForUpdates {
            SUUpdater.shared().checkForUpdatesInBackground()
        }
        
        //Add menuItem to menu
        let menu = NSMenu()
        let prefMenu = NSMenu()
        
        let screenItem = NSMenuItem()
        screenItem.title = "act_screen".localized
        
        for (i,_) in NSScreen.screens()!.enumerated() {
            let name = CFunctions.localizedDisplayProductName(NSScreen.screens()![i])
            screenMenu.addItem(withTitle: name!, action: #selector(AppDelegate.setActiveScreen(_:)), keyEquivalent: "")
        }
        
        var selected = UserDefaults.standard.integer(forKey: "activeScreen")
        let maxScreens =  NSScreen.screens()!.count - 1
        
        if maxScreens < selected {
            selected = 0
            UserDefaults.standard.set(selected, forKey: "activeScreen")
        }
        
        screenMenu.item(at: selected)?.state = NSOnState
        screenItem.submenu = screenMenu
        
        menu.addItem(screenItem)
        menu.addItem(withTitle: "chk_updt".localized, action: #selector(AppDelegate.checkUpdatesAction), keyEquivalent: "")
        
        let prefItem = NSMenuItem()
        prefItem.title = "pref".localized
        
        let startItem = NSMenuItem(title: "open_launch".localized, action: #selector(AppDelegate.toggleLaunchAtStartup(_:)), keyEquivalent: "")
        if UserDefaults.standard.bool(forKey: "launchAtStartup") {
            startItem.state = NSOnState
        }
        prefMenu.addItem(startItem)
        
        let updateAutoItem = NSMenuItem(title: "auto_updt".localized, action: #selector(AppDelegate.toggleAutoUpdates(_:)), keyEquivalent: "")
        if SUUpdater.shared().automaticallyChecksForUpdates {
            updateAutoItem.state = NSOnState
        }
        
        prefMenu.addItem(updateAutoItem)
        prefItem.submenu = prefMenu
        menu.addItem(prefItem)
        menu.addItem(withTitle: "exit".localized, action: #selector(AppDelegate.exitAction), keyEquivalent: "q")
        statusBarItem.menu = menu
        let icon = NSImage(named: "statusIcon")!
        icon.isTemplate = true
        statusBarItem.image = icon
        
        
        mouseHandler = MouseHandler()
    }
    
    func exitAction(){
        NSApp.terminate(self)
    }
    
    func setActiveScreen(_ sender: NSMenuItem) {
        for (i,screen) in screenMenu.items.enumerated() {
            if screen == sender {
                sender.state = NSOnState
                UserDefaults.standard.set(i, forKey: "activeScreen")
            } else {
                screen.state = NSOffState
            }
        }
        
        NotificationCenter.default.post(name: ActiveScreenDidChangeNotification, object: nil)
    }
    
    func checkUpdatesAction() {
        SUUpdater.shared().checkForUpdates(self)
    }
    
    func toggleAutoUpdates(_ sender: NSMenuItem) {
        if sender.state == NSOffState {
            sender.state = NSOnState
        } else if sender.state == NSOnState {
            sender.state = NSOffState
        }
        SUUpdater.shared().automaticallyChecksForUpdates = !SUUpdater.shared().automaticallyChecksForUpdates
    }
    
    func toggleLaunchAtStartup(_ sender: NSMenuItem) {
        if sender.state == NSOffState {
            sender.state = NSOnState
        } else if sender.state == NSOnState {
            sender.state = NSOffState
        }
        toggleLaunchAtStartup()
        let bool = UserDefaults.standard.bool(forKey: "launchAtStartup")
        UserDefaults.standard.set(!bool, forKey: "launchAtStartup")
    }
    
    private func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }
    
    private func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItem?, lastReference: LSSharedFileListItem?) {
        let itemUrl = UnsafeMutablePointer<Unmanaged<CFURL>?>.allocate(capacity: 1)
        let appUrl: URL = URL(fileURLWithPath: Bundle.main.bundlePath)
        
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
            ).takeRetainedValue() as LSSharedFileList?
        if loginItemsRef != nil {
            let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
            print("There are \(loginItems.count) login items")
            if(loginItems.count > 0)
            {
                let lastItemRef: LSSharedFileListItem = loginItems.lastObject as! LSSharedFileListItem
                for i in 0 ..< (loginItems.count + 1) {
                    let currentItemRef: LSSharedFileListItem = loginItems.object(at: i) as! LSSharedFileListItem
                    if LSSharedFileListItemResolve(currentItemRef, 0, itemUrl, nil) == noErr {
                        if let urlRef: URL =  itemUrl.pointee?.takeRetainedValue() as? URL {
                            print("URL Ref: \(urlRef.lastPathComponent)")
                            if urlRef == appUrl {
                                return (currentItemRef, lastItemRef)
                            }
                        }
                    } else {
                        print("Unknown login application")
                    }
                }
                //The application was not found in the startup list
                return (nil, lastItemRef)
            } else {
                let addatstart: LSSharedFileListItem = kLSSharedFileListItemBeforeFirst.takeRetainedValue()
                
                return(nil,addatstart)
            }
        }
        return (nil, nil)
    }
    
    func toggleLaunchAtStartup() {
        let itemReferences = itemReferencesInLoginItems()
        let shouldBeToggled = (itemReferences.existingReference == nil)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
            ).takeRetainedValue() as LSSharedFileList?
        if loginItemsRef != nil {
            if shouldBeToggled {
                let appUrl: CFURL = URL(fileURLWithPath: Bundle.main.bundlePath) as CFURL
                LSSharedFileListInsertItemURL(
                    loginItemsRef,
                    itemReferences.lastReference,
                    nil,
                    nil,
                    appUrl,
                    nil,
                    nil
                )
                print("Application was added to login items")
            } else {
                if let itemRef = itemReferences.existingReference {
                    LSSharedFileListItemRemove(loginItemsRef,itemRef);
                    print("Application was removed from login items")
                }
            }
        }
    }
    
}

