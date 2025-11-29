import Cocoa
import SwiftUI

class BreakOverlayWindow: NSWindow {
    private var coverWindows: [NSWindow] = []
    
    init(timerManager: TimerManager) {
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]
        
        super.init(
            contentRect: mainScreen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.backgroundColor = NSColor.black.withAlphaComponent(0.95)
        self.isOpaque = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let breakView = BreakOverlayView(timerManager: timerManager)
        self.contentView = NSHostingView(rootView: breakView)
        
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
    }
    
    func show() {
        print("🟢 BreakOverlayWindow.show() called")
        
        // Create cover windows for all other screens
        for screen in NSScreen.screens where screen != NSScreen.main {
            let coverWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            coverWindow.level = .screenSaver
            coverWindow.backgroundColor = NSColor.black.withAlphaComponent(0.95)
            coverWindow.isOpaque = false
            coverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            coverWindow.ignoresMouseEvents = false
            coverWindow.isReleasedWhenClosed = false
            
            coverWindows.append(coverWindow)
        }
        
        // Show all windows
        self.orderFrontRegardless()
        for window in coverWindows {
            window.orderFrontRegardless()
        }
        
        NSApp.activate(ignoringOtherApps: true)
        print("🟢 Break window displayed")
    }
    
    func forceClose() {
        print("🔴 forceClose() - NUCLEAR OPTION")
        
        // Destroy content first
        self.contentView = nil
        
        // Force all cover windows out
        for window in coverWindows {
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        coverWindows.removeAll()
        
        // Force this window to back
        self.orderOut(nil)
        self.orderBack(nil)
        
        // Make it invisible
        self.alphaValue = 0
        self.isOpaque = true
        self.backgroundColor = .clear
        
        // Drop to bottom level
        self.level = .normal
        
        // Actually close
        super.close()
        
        print("🔴 forceClose() completed")
    }
    
    override func close() {
        print("🔴 BreakOverlayWindow.close() called")
        forceClose()
    }
    
    deinit {
        print("🔴 BreakOverlayWindow deallocated")
    }
}

struct BreakOverlayView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var remainingTime: TimeInterval = 0
    @State private var progress: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                Text("Time for a break!")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Look away from your screen")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                    .frame(height: 40)
                
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 200, height: 200)
                    
                    // Animated progress circle with gradient
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .blue,
                                    .cyan,
                                    .blue.opacity(0.8),
                                    .cyan.opacity(0.8)
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(353)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                    
                    // Glow effect when almost done
                    if remainingTime <= 5 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color.cyan.opacity(0.3),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                            .blur(radius: 8)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                    
                    // Timer text with smooth number transition
                    Text("\(Int(ceil(max(0, remainingTime))))")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: Int(remainingTime))
                }
        
            }
            .padding()
        }
        .onReceive(timer) { _ in
            let newTime = timerManager.getRemainingBreakTime()
            remainingTime = newTime
            
            // Update progress smoothly
            let totalDuration = timerManager.breakDuration
            if totalDuration > 0 {
                progress = CGFloat(newTime / totalDuration)
            } else {
                progress = 0
            }
        }
        .onAppear {
            remainingTime = timerManager.getRemainingBreakTime()
            let totalDuration = timerManager.breakDuration
            if totalDuration > 0 {
                progress = CGFloat(remainingTime / totalDuration)
            }
            
            // Start pulse animation
            pulseScale = 1.05
            
            print("🟢 BreakOverlayView appeared with time: \(remainingTime)")
        }
    }
}
