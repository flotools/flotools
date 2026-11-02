# Speak/Select Track View

- Group: Flo Tools Inspector
- UID: 6A53AF54-B897-4B37-9CF8-5F15D19B1CE4
- Enabled: True
- Triggers: W

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "w"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.uiElements.whose({title:{_contains:"Track View Selector"}})[0]
  value = button.value()
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.uiElements.whose({title:{_contains:"Track View Selector"}})[0]
  button.click()
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
