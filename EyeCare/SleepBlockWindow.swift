import Cocoa
import SwiftUI

class SleepBlockWindow: NSWindow {
    private var timerManager: TimerManager
    private var hostingView: NSHostingView<SleepBlockView>?
    private var coverWindows: [NSWindow] = []
    
    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]
        
        super.init(
            contentRect: mainScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.backgroundColor = NSColor.black
        self.isOpaque = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let sleepView = SleepBlockView(timerManager: timerManager)
        hostingView = NSHostingView(rootView: sleepView)
        self.contentView = hostingView
    }
    
    func show() {
        coverAllScreens()
        self.orderFrontRegardless()
        
        for window in coverWindows {
            window.orderFrontRegardless()
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func forceClose() {
        print("🔴 forceClose() - Sleep window")
        
        // Force all cover windows out
        for window in coverWindows {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        coverWindows.removeAll()
        
        // Force this window out
        self.contentView = nil
        self.orderOut(nil)
        self.orderBack(nil)
        self.alphaValue = 0
        self.level = .normal
        
        super.close()
        
        print("🔴 Sleep window closed")
    }
    
    override func close() {
        for window in coverWindows {
            window.orderOut(nil)
        }
        coverWindows.removeAll()
        
        self.contentView = nil
        hostingView = nil
        
        self.orderOut(nil)
        super.close()
    }
    
    private func coverAllScreens() {
        for window in coverWindows {
            window.close()
        }
        coverWindows.removeAll()
        
        for screen in NSScreen.screens where screen != NSScreen.main {
            let coverWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            coverWindow.level = .screenSaver
            coverWindow.backgroundColor = NSColor.black
            coverWindow.isOpaque = true
            coverWindow.hasShadow = false
            coverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let sleepView = SleepBlockView(timerManager: timerManager)
            coverWindow.contentView = NSHostingView(rootView: sleepView)
            
            coverWindows.append(coverWindow)
        }
    }
}

struct SleepBlockView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 20)
                
                Text("Sleep Mode Active")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Time to rest 😴")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 10) {
                    Text("Current Time")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(currentTime, style: .time)
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                        .frame(height: 30)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: 300)
                    
                    Spacer()
                        .frame(height: 10)
                    
                    Text("Computer blocked until")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 5) {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(.cyan)
                        Text(String(format: "%02d:%02d", timerManager.sleepEndHour, timerManager.sleepEndMinute))
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    
                    Text(timeUntilWakeMessage)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 10)
                }
                
                Spacer()
                    .frame(height: 40)
                
                VStack(spacing: 10) {
                    Text("🌙 Rest well and come back refreshed")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("This screen will automatically disappear at wake time")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    var timeUntilWakeMessage: String {
        let calendar = Calendar.current
        let now = Date()
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        
        let wakeupTotalMinutes = timerManager.sleepEndHour * 60 + timerManager.sleepEndMinute
        
        var minutesUntilWakeup: Int
        
        if wakeupTotalMinutes > currentTotalMinutes {
            minutesUntilWakeup = wakeupTotalMinutes - currentTotalMinutes
        } else {
            minutesUntilWakeup = (24 * 60) - currentTotalMinutes + wakeupTotalMinutes
        }
        
        let hours = minutesUntilWakeup / 60
        let minutes = minutesUntilWakeup % 60
        
        if hours > 0 {
            return String(format: "(%d hours and %d minutes remaining)", hours, minutes)
        } else {
            return String(format: "(%d minutes remaining)", minutes)
        }
    }
}
