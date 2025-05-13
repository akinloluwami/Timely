import SwiftUI

@main
struct TimelyStopwatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var startTime: Date?
    var elapsedTime: TimeInterval = 0
    var isRunning: Bool = false
    
    // Add notification observers
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupNotificationObservers()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanup()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem.button else {
            print("Error: Failed to create status item button")
            return
        }
        
        button.title = "00:00:00"
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start/Pause", action: #selector(toggleTimer), keyEquivalent: " "))
        menu.addItem(NSMenuItem(title: "Reset", action: #selector(resetTimer), keyEquivalent: "r"))
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
            button.title = formatTime(currentTime)
        }
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 10) % 10
        return String(format: "%02d:%02d:%02d:%d", hours, minutes, seconds, milliseconds)
    }

    @objc func quitApp() {
        cleanup()
        NSApplication.shared.terminate(self)
    }
}
