# Monitor Attack

- Group: Flo Tools
- UID: D7EE1801-A2E8-4FFF-B4BD-A4C8305CE671
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  function read(msg) {
  if (msg == "") msg = "no"
  msg += ". Attack"
  vo.output(msg)
  }
  
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  last = ""
  try {
  last = msg = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Attack Velocity").value()
  } catch(err) {
  }
  read(last)
  while (kme.getvariable("FTEventIndex") == "2") {
  try {
  current = msg = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Attack Velocity").value()
  if (last != current) {
  last = current
  read(current)
  }
  } catch(err) {
  }
  delay(0.1)
  }
  ```
