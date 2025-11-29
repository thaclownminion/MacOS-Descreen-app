import Foundation
import UserNotifications

class TimerManager: ObservableObject {
    @Published var workInterval: TimeInterval = 20 * 60
    @Published var breakDuration: TimeInterval = 20
    @Published var settingsLockDuration: TimeInterval = 5 * 60
    @Published var focusDuration: TimeInterval = 60 * 60
    @Published var isFocusModeActive: Bool = false
    @Published var sleepModeEnabled: Bool = false
    @Published var sleepStartHour: Int = 22
    @Published var sleepStartMinute: Int = 0
    @Published var sleepEndHour: Int = 7
    @Published var sleepEndMinute: Int = 0
    
    // Weekly schedule
    @Published var scheduleEnabled: Bool = false
    @Published var mondayEnabled: Bool = true
    @Published var tuesdayEnabled: Bool = true
    @Published var wednesdayEnabled: Bool = true
    @Published var thursdayEnabled: Bool = true
    @Published var fridayEnabled: Bool = true
    @Published var saturdayEnabled: Bool = false
    @Published var sundayEnabled: Bool = false
    
    // Notification settings
    @Published var notificationsEnabled: Bool = true
    @Published var notificationTiming: [Int] = [5, 2, 1] // minutes before break
    @Published var useSystemNotifications: Bool = true // true = system, false = in-app indicator

    private var notificationSent: Set<Int> = []
    private var workTimer: Timer?
    private var breakTimer: Timer?
    private var focusTimer: Timer?
    private var sleepCheckTimer: Timer?
    private var remainingWorkTime: TimeInterval = 0
    private var remainingBreakTime: TimeInterval = 0
    private var remainingFocusTime: TimeInterval = 0
    private var settingsLockedUntil: Date?
    
    
    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onSettingsChange: (() -> Void)?
    var onFocusUpdate: ((TimeInterval) -> Void)?
    var onSleepModeChange: ((Bool) -> Void)?
    var onBreakWarning: ((Int) -> Void)?
    var onBreakCountdown: ((Int) -> Void)? // New: for live countdown
    
    
    private var isOnBreak = false
    private var isInSleepTime = false
    
    init() {
        loadSettings()
        remainingWorkTime = workInterval
        startSleepModeChecker()
    }
    
    func start() {
        startWorkTimer()
    }
    
    private func startSleepModeChecker() {
        // Check every second for precise timing
        sleepCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkSleepMode()
        }
        checkSleepMode()
    }

    private func checkSleepMode() {
        guard sleepModeEnabled else {
            if isInSleepTime {
                isInSleepTime = false
                onSleepModeChange?(false)
            }
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        let sleepStartTotalMinutes = sleepStartHour * 60 + sleepStartMinute
        let sleepEndTotalMinutes = sleepEndHour * 60 + sleepEndMinute
        let currentTotalMinutes = currentHour * 60 + currentMinute
        
        let inSleepTime: Bool
        
        if sleepStartTotalMinutes < sleepEndTotalMinutes {
            // Sleep time doesn't cross midnight (e.g., 14:00 to 18:00)
            inSleepTime = currentTotalMinutes >= sleepStartTotalMinutes && currentTotalMinutes < sleepEndTotalMinutes
        } else {
            // Sleep time crosses midnight (e.g., 22:00 to 07:00)
            inSleepTime = currentTotalMinutes >= sleepStartTotalMinutes || currentTotalMinutes < sleepEndTotalMinutes
        }
        
        // Trigger callback when state changes
        if inSleepTime != isInSleepTime {
            isInSleepTime = inSleepTime
            print(inSleepTime ? "🌙 Entering sleep mode - BLOCKING SCREEN" : "☀️ Exiting sleep mode - UNBLOCKING SCREEN")
            onSleepModeChange?(inSleepTime)
        }
    }
    
    func isCurrentlyInSleepTime() -> Bool {
        return sleepModeEnabled && isInSleepTime
    }
    
    func forceSleepCheck() {
        checkSleepMode()
    }
    
    private func isTodayEnabled() -> Bool {
        if !scheduleEnabled {
            return true
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        switch weekday {
        case 1: return sundayEnabled
        case 2: return mondayEnabled
        case 3: return tuesdayEnabled
        case 4: return wednesdayEnabled
        case 5: return thursdayEnabled
        case 6: return fridayEnabled
        case 7: return saturdayEnabled
        default: return true
        }
    }
    
    private func startWorkTimer() {
        workTimer?.invalidate()
        remainingWorkTime = workInterval
        notificationSent.removeAll() // Reset notifications
        
        workTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isFocusModeActive || self.isInSleepTime || !self.isTodayEnabled() {
                self.onTimeUpdate?(self.remainingWorkTime)
                return
            }
            
            self.remainingWorkTime -= 1
            self.onTimeUpdate?(self.remainingWorkTime)
            
            // Check for notifications
            self.checkAndSendNotifications()
            
            if self.remainingWorkTime <= 0 {
                self.startBreak()
            }
        }
    }
    
    private func checkAndSendNotifications() {
        guard notificationsEnabled else { return }
        
        let minutesRemaining = Int(remainingWorkTime / 60)
        let secondsRemaining = Int(remainingWorkTime)
        let secondsInMinute = Int(remainingWorkTime.truncatingRemainder(dividingBy: 60))
        
        // Send initial notifications at specific minutes
        if secondsInMinute <= 1 {
            for timing in notificationTiming {
                if minutesRemaining == timing && !notificationSent.contains(timing) {
                    notificationSent.insert(timing)
                    sendBreakNotification(minutesRemaining: timing)
                }
            }
        }
        
        // If using in-app and we're under 1 minute, send countdown updates
        if !useSystemNotifications && secondsRemaining <= 60 && secondsRemaining > 0 {
            onBreakCountdown?(secondsRemaining)
        }
        
        // Reset notification tracking when work interval restarts
        if remainingWorkTime == workInterval {
            notificationSent.removeAll()
        }
    }

    private func sendBreakNotification(minutesRemaining: Int) {
        if useSystemNotifications {
            // System notification
            let content = UNMutableNotificationContent()
            content.title = "Break Coming Soon"
            content.body = "Your eye break will start in \(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s")"
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
            
            print("📬 System notification sent: \(minutesRemaining) min remaining")
        } else {
            // In-app indicator (handled by AppDelegate)
            print("📱 In-app notification: \(minutesRemaining) min remaining")
            onBreakWarning?(minutesRemaining)
        }
    }
    
    private func startBreak() {
        print("⏰ BREAK STARTING - Duration: \(breakDuration) seconds")
        workTimer?.invalidate()
        workTimer = nil
        isOnBreak = true
        remainingBreakTime = breakDuration
        
        DispatchQueue.main.async {
            self.onBreakStart?()
        }
        
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.remainingBreakTime -= 1
            print("⏱️ Break remaining: \(self.remainingBreakTime) seconds")
            
            if self.remainingBreakTime <= 0 {
                print("✅ BREAK ENDING - Timer hit 0")
                timer.invalidate()
                self.breakTimer = nil
                self.forceEndBreak()
            }
        }
    }
    
    private func forceEndBreak() {
        print("🔴 forceEndBreak() called")
        
        breakTimer?.invalidate()
        breakTimer = nil
        
        isOnBreak = false
        remainingBreakTime = 0
        
        print("🔴 Calling onBreakEnd callback NOW")
        
        DispatchQueue.main.async {
            self.onBreakEnd?()
            print("🔴 onBreakEnd callback executed (attempt 1)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onBreakEnd?()
            print("🔴 onBreakEnd callback executed (attempt 2)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 Restarting work timer")
            self.startWorkTimer()
        }
    }
    
    func triggerBreakNow() {
        if !isOnBreak && !isFocusModeActive && !isInSleepTime && isTodayEnabled() {
            workTimer?.invalidate()
            startBreak()
        }
    }
    
    func getRemainingBreakTime() -> TimeInterval {
        return max(0, remainingBreakTime)
    }
    
    func startFocusMode() {
        isFocusModeActive = true
        remainingFocusTime = focusDuration
        
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingFocusTime -= 1
            self.onFocusUpdate?(self.remainingFocusTime)
            
            if self.remainingFocusTime <= 0 {
                self.endFocusMode()
            }
        }
        
        onSettingsChange?()
    }
    
    func endFocusMode() {
        focusTimer?.invalidate()
        isFocusModeActive = false
        remainingFocusTime = 0
        onFocusUpdate?(0)
        onSettingsChange?()
    }
    
    func getRemainingFocusTime() -> TimeInterval {
        return remainingFocusTime
    }
    
    func updateSettings(work: TimeInterval, breakTime: TimeInterval, lockTime: TimeInterval, focusTime: TimeInterval) {
        workInterval = work
        breakDuration = breakTime
        settingsLockDuration = lockTime
        focusDuration = focusTime
        
        saveSettings()
        
        if lockTime > 0 {
            lockSettings()
            print("🔒 Settings locked for \(lockTime) seconds")
        } else {
            print("⚠️ Lock time is 0, not locking settings")
        }
        
        onSettingsChange?()
        
        if !isOnBreak {
            startWorkTimer()
        }
    }
    
    func updateSleepSettings(enabled: Bool, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        sleepModeEnabled = enabled
        sleepStartHour = startHour
        sleepStartMinute = startMinute
        sleepEndHour = endHour
        sleepEndMinute = endMinute
        
        saveSleepSettings()
        checkSleepMode()
    }
    
    func updateScheduleSettings() {
        saveScheduleSettings()
        onSettingsChange?()
    }
    
    func isSettingsLocked() -> Bool {
        guard let lockedUntil = settingsLockedUntil else {
            print("🔓 No lock time set, settings unlocked")
            return false
        }
        
        let isLocked = Date() < lockedUntil
        
        if isLocked {
            let remaining = lockedUntil.timeIntervalSince(Date())
            print("🔒 Settings are locked for \(Int(remaining)) more seconds")
        } else {
            print("🔓 Settings lock has expired")
        }
        
        return isLocked
    }
    
    func getRemainingLockTime() -> TimeInterval {
        guard let lockedUntil = settingsLockedUntil else { return 0 }
        return max(0, lockedUntil.timeIntervalSince(Date()))
    }
    
    private func lockSettings() {
        let lockUntil = Date().addingTimeInterval(settingsLockDuration)
        settingsLockedUntil = lockUntil
        
        print("🔒 Settings locked until: \(lockUntil)")
        print("🔒 Lock duration: \(settingsLockDuration) seconds (\(Int(settingsLockDuration / 60)) minutes)")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(workInterval, forKey: "workInterval")
        UserDefaults.standard.set(breakDuration, forKey: "breakDuration")
        UserDefaults.standard.set(settingsLockDuration, forKey: "settingsLockDuration")
        UserDefaults.standard.set(focusDuration, forKey: "focusDuration")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(useSystemNotifications, forKey: "useSystemNotifications")
        UserDefaults.standard.set(notificationTiming, forKey: "notificationTiming")
    }
    
    func saveSleepSettings() {
        UserDefaults.standard.set(sleepModeEnabled, forKey: "sleepModeEnabled")
        UserDefaults.standard.set(sleepStartHour, forKey: "sleepStartHour")
        UserDefaults.standard.set(sleepStartMinute, forKey: "sleepStartMinute")
        UserDefaults.standard.set(sleepEndHour, forKey: "sleepEndHour")
        UserDefaults.standard.set(sleepEndMinute, forKey: "sleepEndMinute")
    }
    
    func saveScheduleSettings() {
        UserDefaults.standard.set(scheduleEnabled, forKey: "scheduleEnabled")
        UserDefaults.standard.set(mondayEnabled, forKey: "mondayEnabled")
        UserDefaults.standard.set(tuesdayEnabled, forKey: "tuesdayEnabled")
        UserDefaults.standard.set(wednesdayEnabled, forKey: "wednesdayEnabled")
        UserDefaults.standard.set(thursdayEnabled, forKey: "thursdayEnabled")
        UserDefaults.standard.set(fridayEnabled, forKey: "fridayEnabled")
        UserDefaults.standard.set(saturdayEnabled, forKey: "saturdayEnabled")
        UserDefaults.standard.set(sundayEnabled, forKey: "sundayEnabled")
    }
    
    private func loadSettings() {
        let savedWork = UserDefaults.standard.double(forKey: "workInterval")
        let savedBreak = UserDefaults.standard.double(forKey: "breakDuration")
        let savedLock = UserDefaults.standard.double(forKey: "settingsLockDuration")
        let savedFocus = UserDefaults.standard.double(forKey: "focusDuration")
        
        if savedWork > 0 { workInterval = savedWork }
        if savedBreak > 0 { breakDuration = savedBreak }
        if savedLock > 0 { settingsLockDuration = savedLock }
        if savedFocus > 0 { focusDuration = savedFocus }
        
        // Load notification settings
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        useSystemNotifications = UserDefaults.standard.object(forKey: "useSystemNotifications") as? Bool ?? true
        if let savedTiming = UserDefaults.standard.array(forKey: "notificationTiming") as? [Int], !savedTiming.isEmpty {
            notificationTiming = savedTiming
        }
        
        sleepModeEnabled = UserDefaults.standard.bool(forKey: "sleepModeEnabled")
        let savedStartHour = UserDefaults.standard.integer(forKey: "sleepStartHour")
        let savedStartMinute = UserDefaults.standard.integer(forKey: "sleepStartMinute")
        let savedEndHour = UserDefaults.standard.integer(forKey: "sleepEndHour")
        let savedEndMinute = UserDefaults.standard.integer(forKey: "sleepEndMinute")
        
        if UserDefaults.standard.object(forKey: "sleepStartHour") != nil {
            sleepStartHour = savedStartHour
            sleepStartMinute = savedStartMinute
            sleepEndHour = savedEndHour
            sleepEndMinute = savedEndMinute
        }
        
        scheduleEnabled = UserDefaults.standard.bool(forKey: "scheduleEnabled")
        if UserDefaults.standard.object(forKey: "mondayEnabled") != nil {
            mondayEnabled = UserDefaults.standard.bool(forKey: "mondayEnabled")
            tuesdayEnabled = UserDefaults.standard.bool(forKey: "tuesdayEnabled")
            wednesdayEnabled = UserDefaults.standard.bool(forKey: "wednesdayEnabled")
            thursdayEnabled = UserDefaults.standard.bool(forKey: "thursdayEnabled")
            fridayEnabled = UserDefaults.standard.bool(forKey: "fridayEnabled")
            saturdayEnabled = UserDefaults.standard.bool(forKey: "saturdayEnabled")
            sundayEnabled = UserDefaults.standard.bool(forKey: "sundayEnabled")
        }
    }
}
