# Monitor Pitch

- Group: Flo Tools
- UID: 64AD6935-BC5A-4A2C-A7EC-6CF57B3DDE74
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  function read(msg) {
  msg = msg.replace("x", "-DOUBLE Sharp")
  msg = msg.replace("#", "-Sharp ")
  msg = msg.replace("bb", "-DOUBLE Flat")
  msg = msg.replace("b", "-Flat ")
  if (msg=="") msg = "No"
  msg += ". Pitch"
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
  last = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Pitch").value()
  } catch(err) {
  }
  read(last)
  while (kme.getvariable("FTEventIndex") == "1") {
  try {
  current = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Pitch").value()
  if (last != current) {
  last = current
  read(current)
  }
  } catch(err) {
  }
  delay(0.1)
  }
  ```
