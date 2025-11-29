import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager
    weak var appDelegate: AppDelegate?
    
    @State private var workMinutes: Double
    @State private var breakSeconds: Double
    @State private var lockMinutes: Double
    @State private var focusMinutes: Double
    @State private var preventQuit: Bool = UserDefaults.standard.bool(forKey: "preventQuit")
    @State private var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin")
    
    @State private var notificationsEnabled: Bool
    @State private var useSystemNotifications: Bool
    @State private var notification5min: Bool
    @State private var notification2min: Bool
    @State private var notification1min: Bool
    @State private var sleepModeEnabled: Bool
    @State private var sleepStartHour: Int
    @State private var sleepStartMinute: Int
    @State private var sleepEndHour: Int
    @State private var sleepEndMinute: Int
    
    @State private var scheduleEnabled: Bool
    @State private var mondayEnabled: Bool
    @State private var tuesdayEnabled: Bool
    @State private var wednesdayEnabled: Bool
    @State private var thursdayEnabled: Bool
    @State private var fridayEnabled: Bool
    @State private var saturdayEnabled: Bool
    @State private var sundayEnabled: Bool
    
    init(timerManager: TimerManager, appDelegate: AppDelegate?) {
        self.timerManager = timerManager
        self.appDelegate = appDelegate
        _workMinutes = State(initialValue: timerManager.workInterval / 60)
        _breakSeconds = State(initialValue: timerManager.breakDuration)
        _lockMinutes = State(initialValue: timerManager.settingsLockDuration / 60)
        _focusMinutes = State(initialValue: timerManager.focusDuration / 60)
        
        _sleepModeEnabled = State(initialValue: timerManager.sleepModeEnabled)
        _sleepStartHour = State(initialValue: timerManager.sleepStartHour)
        _sleepStartMinute = State(initialValue: timerManager.sleepStartMinute)
        _sleepEndHour = State(initialValue: timerManager.sleepEndHour)
        _sleepEndMinute = State(initialValue: timerManager.sleepEndMinute)
        
        _scheduleEnabled = State(initialValue: timerManager.scheduleEnabled)
        _mondayEnabled = State(initialValue: timerManager.mondayEnabled)
        _tuesdayEnabled = State(initialValue: timerManager.tuesdayEnabled)
        _wednesdayEnabled = State(initialValue: timerManager.wednesdayEnabled)
        _thursdayEnabled = State(initialValue: timerManager.thursdayEnabled)
        _fridayEnabled = State(initialValue: timerManager.fridayEnabled)
        _saturdayEnabled = State(initialValue: timerManager.saturdayEnabled)
        _sundayEnabled = State(initialValue: timerManager.sundayEnabled)
        
        _notificationsEnabled = State(initialValue: timerManager.notificationsEnabled)
        _useSystemNotifications = State(initialValue: timerManager.useSystemNotifications)
        _notification5min = State(initialValue: timerManager.notificationTiming.contains(5))
        _notification2min = State(initialValue: timerManager.notificationTiming.contains(2))
        _notification1min = State(initialValue: timerManager.notificationTiming.contains(1))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Eye Care Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 20)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Work Interval")
                            .font(.headline)
                        Text("\(Int(workMinutes)) minutes")
                            .foregroundColor(.secondary)
                        Slider(value: $workMinutes, in: 1...120, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Break Duration")
                            .font(.headline)
                        Text("\(Int(breakSeconds)) seconds")
                            .foregroundColor(.secondary)
                        Slider(value: $breakSeconds, in: 10...300, step: 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus Mode Duration")
                            .font(.headline)
                        Text("\(Int(focusMinutes)) minutes")
                            .foregroundColor(.secondary)
                        Slider(value: $focusMinutes, in: 15...180, step: 5)
                        Text("No breaks during focus mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings Lock Time")
                            .font(.headline)
                        Text("\(Int(lockMinutes)) minutes")
                            .foregroundColor(.secondary)
                        Slider(value: $lockMinutes, in: 0...60, step: 1)
                        Text("Settings will lock after saving changes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()

                    // Break Notifications
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Enable Break Notifications", isOn: $notificationsEnabled)
                            .font(.headline)
                        
                        if notificationsEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Notification Type")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $useSystemNotifications) {
                                    Text("System Notifications").tag(true)
                                    Text("In-App Indicator").tag(false)
                                }
                                .pickerStyle(.segmented)
                                
                                Text("Notify me before break:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 5)
                                
                                Toggle("5 minutes before", isOn: $notification5min)
                                Toggle("2 minutes before", isOn: $notification2min)
                                Toggle("1 minute before", isOn: $notification1min)
                                
                                Text(useSystemNotifications ?
                                    "System notifications appear in Notification Center" :
                                    "In-app indicator shows at top-right of screen")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 5)
                            }
                            .padding(.leading, 10)
                        }
                    }
                    
                    // Weekly Schedule
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Enable Weekly Schedule", isOn: $scheduleEnabled)
                            .font(.headline)
                            .onChange(of: scheduleEnabled) { oldValue, newValue in
                                timerManager.scheduleEnabled = newValue
                                timerManager.updateScheduleSettings()
                            }
                        
                        if scheduleEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Active Days")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Toggle("Monday", isOn: $mondayEnabled)
                                    .onChange(of: mondayEnabled) { oldValue, newValue in
                                        timerManager.mondayEnabled = newValue
                                    }
                                Toggle("Tuesday", isOn: $tuesdayEnabled)
                                    .onChange(of: tuesdayEnabled) { oldValue, newValue in
                                        timerManager.tuesdayEnabled = newValue
                                    }
                                Toggle("Wednesday", isOn: $wednesdayEnabled)
                                    .onChange(of: wednesdayEnabled) { oldValue, newValue in
                                        timerManager.wednesdayEnabled = newValue
                                    }
                                Toggle("Thursday", isOn: $thursdayEnabled)
                                    .onChange(of: thursdayEnabled) { oldValue, newValue in
                                        timerManager.thursdayEnabled = newValue
                                    }
                                Toggle("Friday", isOn: $fridayEnabled)
                                    .onChange(of: fridayEnabled) { oldValue, newValue in
                                        timerManager.fridayEnabled = newValue
                                    }
                                Toggle("Saturday", isOn: $saturdayEnabled)
                                    .onChange(of: saturdayEnabled) { oldValue, newValue in
                                        timerManager.saturdayEnabled = newValue
                                    }
                                Toggle("Sunday", isOn: $sundayEnabled)
                                    .onChange(of: sundayEnabled) { oldValue, newValue in
                                        timerManager.sundayEnabled = newValue
                                    }
                                
                                Text("Breaks only happen on selected days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 10)
                        }
                    }
                    
                    Divider()
                    
                    // Sleep Mode Settings
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Enable Sleep Mode", isOn: $sleepModeEnabled)
                            .font(.headline)
                        
                        if sleepModeEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Sleep Start Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Picker("Hour", selection: $sleepStartHour) {
                                        ForEach(0..<24) { hour in
                                            Text(String(format: "%02d", hour)).tag(hour)
                                        }
                                    }
                                    .frame(width: 80)
                                    
                                    Text(":")
                                    
                                    Picker("Minute", selection: $sleepStartMinute) {
                                        ForEach(0..<60) { minute in
                                            Text(String(format: "%02d", minute)).tag(minute)
                                        }
                                    }
                                    .frame(width: 80)
                                    
                                    Spacer()
                                }
                                
                                Text("Sleep End Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 5)
                                
                                HStack {
                                    Picker("Hour", selection: $sleepEndHour) {
                                        ForEach(0..<24) { hour in
                                            Text(String(format: "%02d", hour)).tag(hour)
                                        }
                                    }
                                    .frame(width: 80)
                                    
                                    Text(":")
                                    
                                    Picker("Minute", selection: $sleepEndMinute) {
                                        ForEach(0..<60) { minute in
                                            Text(String(format: "%02d", minute)).tag(minute)
                                        }
                                    }
                                    .frame(width: 80)
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Image(systemName: "moon.stars.fill")
                                        .foregroundColor(.yellow)
                                    Text("Computer will be fully blocked during sleep time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 5)
                                
                                Text("The sleep block screen will remain until wake time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 10)
                        }
                    }
                    
                    Divider()
                    
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { oldValue, newValue in
                            if newValue {
                                appDelegate?.enableLaunchAtLogin()
                            } else {
                                appDelegate?.disableLaunchAtLogin()
                            }
                        }
                    
                    Text("Start Eye Care automatically when you log in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Toggle("Prevent quitting the app", isOn: $preventQuit)
                        .onChange(of: preventQuit) { oldValue, newValue in
                            UserDefaults.standard.set(newValue, forKey: "preventQuit")
                            timerManager.onSettingsChange?()
                        }
                    
                    Text("When enabled, quitting requires confirmation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 30)
                
                Button(action: saveSettings) {
                    Text("Save Settings")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 30)
                                    .padding(.bottom, 20)
                                }
                            }
                            .frame(width: 400, height: 800)
                            .background(Color(NSColor.windowBackgroundColor))
                        }
                        
    func saveSettings() {
        print("💾 Saving settings...")
        print("💾 Lock time set to: \(Int(lockMinutes)) minutes")
        
        let manager = timerManager
        
        manager.updateSettings(
            work: workMinutes * 60,
            breakTime: breakSeconds,
            lockTime: lockMinutes * 60,
            focusTime: focusMinutes * 60
        )
        
        manager.updateSleepSettings(
            enabled: sleepModeEnabled,
            startHour: sleepStartHour,
            startMinute: sleepStartMinute,
            endHour: sleepEndHour,
            endMinute: sleepEndMinute
        )
        
        manager.updateScheduleSettings()
        
        // Save notification settings
        manager.notificationsEnabled = notificationsEnabled
        manager.useSystemNotifications = useSystemNotifications
        
        var timings: [Int] = []
        if notification5min { timings.append(5) }
        if notification2min { timings.append(2) }
        if notification1min { timings.append(1) }
        manager.notificationTiming = timings.sorted(by: >)
        
        manager.saveSettings()
        
        // Force immediate sleep mode check
        print("🔍 Checking if currently in sleep time...")
        manager.forceSleepCheck()
        
        // Show confirmation if settings are locked
        if lockMinutes > 0 {
            let alert = NSAlert()
            alert.messageText = "Settings Saved & Locked 🔒"
            alert.informativeText = String(format: "Your settings have been saved and are now locked for %d minutes to help maintain your eye care routine.", Int(lockMinutes))
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        // Show sleep mode warning if entering sleep mode
        if manager.isCurrentlyInSleepTime() {
            print("⚠️ User is in sleep time - screen will be blocked!")
        }
        
        if let window = NSApp.windows.first(where: { $0.title == "Eye Care Settings" }) {
            window.close()
        }
    }
                    }
