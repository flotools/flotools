# Speak And Select Track/Show Right-Click Menu

- Group: Flo Tools Inspector
- UID: ADBCEFDF-6ADF-47B1-8926-F0A37E2B81C1
- Enabled: True
- Triggers: T

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = 't'
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  button = track.popUpButtons.whose({title:{_contains:"Track name"}})[0]
  value = button.name()
  value = value.replace("Track name", "")
  button.click()
  vo.output(value+" selected")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  button = track.popUpButtons.whose({title:{_contains:"Track name"}})[0]
  button.actions['AXShowMenu'].perform()
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
