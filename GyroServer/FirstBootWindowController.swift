//
//  FirstBootWindowController.swift
//  GyroServer
//
//  Created by Matteo Riva on 07/09/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

import Cocoa

class FirstBootWindowController: NSWindowController {
    
    @IBOutlet weak var runAtStartupCheckButton: NSButton!
    @IBOutlet weak var activeScreenListButton: NSPopUpButton!
    @IBOutlet weak var doneButton: NSButton!
    
    var completion: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(OSX 10.10, *) {
            self.window?.styleMask = [self.window!.styleMask, .fullSizeContentView]
            //window.window?.appearance = NSAppearance(appearanceNamed: NSAppearanceNameVibrantLight, bundle: nil)
            self.window?.titleVisibility = .hidden
            self.window?.titlebarAppearsTransparent = true
        }
        
        
        let style = NSMutableParagraphStyle()
        style.alignment = NSCenterTextAlignment
        let attrsDictionary = [NSForegroundColorAttributeName:blue, NSParagraphStyleAttributeName:style]
        let attrString = NSAttributedString(string: runAtStartupCheckButton.title, attributes: attrsDictionary)
        runAtStartupCheckButton.attributedTitle = attrString
        
        self.window?.backgroundColor = NSColor.white
        updateWindowTitlebar()
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        activeScreenListButton.removeAllItems()
        for (i,_) in NSScreen.screens()!.enumerated() {
            let name = CFunctions.localizedDisplayProductName(NSScreen.screens()![i])
            activeScreenListButton.addItem(withTitle: name!)
        }
        
        toggleLaunchAtStartup(nil)
    }
    
    @IBAction func toggleLaunchAtStartup(_ sender: AnyObject?) {
        (NSApplication.shared().delegate as! AppDelegate).toggleLaunchAtStartup()
        UserDefaults.standard.set(true, forKey: "launchAtStartup")
    }
    
    @IBAction func setActiveScreenAction(_ sender: NSPopUpButton) {
        let i = sender.indexOfSelectedItem
        UserDefaults.standard.set(i, forKey: "activeScreen")
        NotificationCenter.default.post(name: ActiveScreenDidChangeNotification, object: nil)
    }
    
    @IBAction func doneAction(_ sender: AnyObject) {
        UserDefaults.standard.set(true, forKey: "firstBoot")
        self.close()
        completion?()
    }
    
    func updateWindowTitlebar() {
        let kTitlebarHeight: CGFloat = 50
        let kFullScreenButtonYOrigin: CGFloat = 3
        let windowFrame = self.window!.frame
        let fullScreen = (self.window!.styleMask.rawValue & NSWindowStyleMask.fullScreen.rawValue) == NSWindowStyleMask.fullScreen.rawValue
        
        // Set size of titlebar container
        let titlebarContainerView = self.window!.standardWindowButton(.closeButton)!.superview!.superview!
        var titlebarContainerFrame = titlebarContainerView.frame
        titlebarContainerFrame.origin.y = windowFrame.size.height - kTitlebarHeight
        titlebarContainerFrame.size.height = kTitlebarHeight
        titlebarContainerView.frame = titlebarContainerFrame
        
        // Set position of window buttons
        var x: CGFloat = 12 // initial LHS margin, matching Safari 8.0 on OS X 10.10.
        let updateButton = {(buttonView: NSView) in
            var buttonFrame = buttonView.frame
            
            // in fullscreen, the titlebar frame is not governed by kTitlebarHeight but rather appears to be fixed by the system.
            // thus, we set a constant Y origin for the buttons when in fullscreen.
            buttonFrame.origin.y = fullScreen ?
                kFullScreenButtonYOrigin :
                round((kTitlebarHeight - buttonFrame.size.height) / 2.0);
            
            buttonFrame.origin.x = x;
            
            // spacing for next button, matching Safari 8.0 on OS X 10.10.
            x += buttonFrame.size.width + 6;
            
            buttonView.setFrameOrigin(buttonFrame.origin)
        }
        
        updateButton(self.window!.standardWindowButton(.closeButton)!)
        updateButton(self.window!.standardWindowButton(.miniaturizeButton)!)
        updateButton(self.window!.standardWindowButton(.zoomButton)!)
    }
    
}
