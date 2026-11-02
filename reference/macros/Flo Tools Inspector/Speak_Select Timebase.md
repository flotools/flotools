# Speak/Select Timebase

- Group: Flo Tools Inspector
- UID: 87F99400-977E-4A95-9FD5-3918BEAF93CE
- Enabled: True
- Triggers: B

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "b"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.uiElements.whose({name:{_contains:"Timebase selector"}})[0]
  value = button.name().replace("Timebase selector", "")
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.uiElements.whose({name:{_contains:"Timebase selector"}})[0].click()
  }
  
  kme = Application("Keyboard Maestro Engine")
  command = kme.getvariable("command").split(".")
  start = new Date().getTime()
  kme.setvariable("command", {to:currentCommand+"."+start})
  if (currentCommand == command[0] & start-command[1]<kme.getvariable("FTTimeout")) {
  double()
  } else  {
  runSingle = true
  while (new Date().getTime()-start<kme.getvariable("FTTimeout")) {
  command = kme.getvariable("command").split(".")
  if (currentCommand == command[0] & command[1]>start) {
  runSingle=false
  break;
  }
  }
  if (runSingle) single()
  }
  
  ```
