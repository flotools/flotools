# Edit Event

- Group: Flo Tools
- UID: 2E052137-AB4B-41B0-A27F-1CA97EDA1D39
- Enabled: True
- Triggers: Ctrl+Cmd+Return

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  c = kme.getvariable("FTEventIndex")
  if (c<-1) c=-1
  else if (c>5) c=5
  kme.setvariable("FTEventIndex", {to:""+c})
  sys = Application('System Events')
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  msg = ""
  if (c==0) {
  edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection Start").click()
  msg="Type start value."
  }else if (c==1) {
  edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Pitch").click()
  msg="Type pitch value."
  }else if (c==2) {
  edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Attack Velocity").click()
  msg="Type Attack velocity value."
  }else if (c==3) {
  edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Release Velocity").click()
  msg="Type Release value."
  } else if (c==4) {
  length = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection Length").click()
  msg="Type length value."
  } else if (c==5) {
  edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection End").click()
  msg="Type end value."
  }
  Application("VoiceOver").output(msg)
  ```
