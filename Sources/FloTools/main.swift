import AppKit
import FloSystem

// First, before the delegate loads the preferences, so a relaunch while logging is on keeps every startup entry.
let resumedLog = Log.resumeRecording()
let app = NSApplication.shared
let delegate = AppDelegate(resumedLog: resumedLog)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
