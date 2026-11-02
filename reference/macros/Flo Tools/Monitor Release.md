# Monitor Release

- Group: Flo Tools
- UID: 6416169E-740D-416B-811A-68DBBB80B9B9
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  function read(msg) {
  if (msg == "") msg = "No"
  msg += ". Release"
  vo.output(msg)
  }
  
  kme = Application("Keyboard Maestro Engine")
  c = kme.getvariable("FTEventIndex")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  last = ""
  try {
  last = msg = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Release Velocity").value()
  } catch(err) {
  }
  read(last)
  while (kme.getvariable("FTEventIndex") == "3") {
  try {
  current = msg = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Release Velocity").value()
  if (last != current) {
  last = current
  read(current)
  }
  } catch(err) {
  }
  delay(0.1)
  }
  ```
