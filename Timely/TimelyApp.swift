import SwiftUI

@main
struct TimelyStopwatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @AppStorage("showMilliseconds") private var showMilliseconds = true
    @AppStorage("startOnLaunch") private var startOnLaunch = false
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    
    var body: some View {
        Form {
            Toggle("Show Milliseconds", isOn: $showMilliseconds)
            Toggle("Start Timer on Launch", isOn: $startOnLaunch)
            Toggle("Always on Top", isOn: $alwaysOnTop)
            
            Text("Keyboard Shortcuts:")
                .font(.headline)
                .padding(.top)
            
            Group {
                Text("• Left Click: Start/Pause")
                Text("• Double Click: Reset")
                Text("• Right Click: Show Menu")
            }
            .font(.system(.body, design: .monospaced))
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var startTime: Date?
    var elapsedTime: TimeInterval = 0
    var isRunning: Bool = false
    var settingsWindow: NSWindow?
    
    // Sound effects
    private let startSound = NSSound(named: "Tink")
    private let stopSound = NSSound(named: "Pop")
    
    // Add notification observers
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupNotificationObservers()
        
        // Start timer on launch if enabled
        if UserDefaults.standard.bool(forKey: "startOnLaunch") {
            startTimer()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanup()
    }
    
    private func setupStatusItem() {
        // Set fixed width for the status item
        statusItem = NSStatusBar.system.statusItem(withLength: 120)
        
        guard let button = statusItem.button else {
            print("Error: Failed to create status item button")
            return
        }
        
        // Configure button properties
        button.imagePosition = .imageLeft
        button.imageHugsTitle = true
        
        // Create attributed string with icon and time
        let timeString = "00:00:00:0"
        let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
        image?.size = NSSize(width: 16, height: 16)
        
        let attributedString = NSMutableAttributedString()
        
        // Add clock icon
        if let image = image {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = image
            let imageString = NSAttributedString(attachment: imageAttachment)
            attributedString.append(imageString)
            attributedString.append(NSAttributedString(string: " "))
        }
        
        // Add time with fixed-width font
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        ]
        attributedString.append(NSAttributedString(string: timeString, attributes: timeAttributes))
        
        button.attributedTitle = attributedString
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start/Pause", action: #selector(toggleTimer), keyEquivalent: " "))
        menu.addItem(NSMenuItem(title: "Reset", action: #selector(resetTimer), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Timely", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Set up click handling
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        clickGesture.buttonMask = 0x1 // Left click
        button.addGestureRecognizer(clickGesture)
        
        // Set up double-click handling
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.buttonMask = 0x1 // Left click
        doubleClickGesture.numberOfClicksRequired = 2
        button.addGestureRecognizer(doubleClickGesture)
        
        // Set up right-click menu
        statusItem.menu = menu
    }
    
    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        if gesture.buttonMask == 0x1 { // Left click
            toggleTimer()
        }
    }
    
    @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        if gesture.buttonMask == 0x1 { // Left click
            resetTimer()
        }
    }
    
    private func setupNotificationObservers() {
        // Observe app activation/deactivation
        let activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppActivation()
        }
        
        let deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDeactivation()
        }
        
        observers.append(contentsOf: [activationObserver, deactivationObserver])
    }
    
    private func handleAppActivation() {
        if isRunning {
            startTimer()
        }
    }
    
    private func handleAppDeactivation() {
        if isRunning {
            pauseTimer()
        }
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        
        // Remove notification observers
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    @objc func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    func startTimer() {
        isRunning = true
        startTime = Date() - elapsedTime
        
        // Play start sound
        startSound?.play()
        
        // Ensure timer is created on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Invalidate existing timer if any
            self.timer?.invalidate()
            
            // Create new timer with shorter interval for smoother updates
            let newTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                self?.updateTime()
            }
            
            // Add to run loop
            RunLoop.current.add(newTimer, forMode: .common)
            
            // Store the timer
            self.timer = newTimer
        }
    }

    func pauseTimer() {
        isRunning = false
        elapsedTime = Date().timeIntervalSince(startTime ?? Date())
        
        // Play stop sound
        stopSound?.play()
        
        timer?.invalidate()
        timer = nil
    }

    @objc func resetTimer() {
        pauseTimer()
        elapsedTime = 0
        if let button = statusItem.button {
            button.title = "00:00:00"
        }
    }

    func updateTime() {
        let currentTime = Date().timeIntervalSince(startTime ?? Date())
        if let button = statusItem.button {
            let timeString = formatTime(currentTime)
            
            // Create attributed string with icon and time
            let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timer")
            image?.size = NSSize(width: 16, height: 16)
            
            let attributedString = NSMutableAttributedString()
            
            // Add clock icon
            if let image = image {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = image
                let imageString = NSAttributedString(attachment: imageAttachment)
                attributedString.append(imageString)
                attributedString.append(NSAttributedString(string: " "))
            }
            
            // Add time with fixed-width font
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            attributedString.append(NSAttributedString(string: timeString, attributes: timeAttributes))
            
            button.attributedTitle = attributedString
        }
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if UserDefaults.standard.bool(forKey: "showMilliseconds") {
            let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 10) % 10
            return String(format: "%02d:%02d:%02d:%d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    @objc func quitApp() {
        cleanup()
        NSApplication.shared.terminate(self)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Timely Settings"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
