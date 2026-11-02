# Speak/Toggle Tab to Transients

- Group: Flo Tools
- UID: 2DCC00FB-9F88-4A22-A546-8B776D1312E9
- Enabled: True
- Triggers: Opt+Cmd+Tab

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "COTab"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("Cursor Tool Cluster").buttons.byName("Tab to Transients").value()
  if (value == "Selected") vo.output ("Tab to Transients, On")
  else vo.output("Tab to Transients, Off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("Cursor Tool Cluster").buttons.byName("Tab to Transients")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Tab to Transients, On")
  else vo.output("Tab to Transients, Off")
  }
  
  kme = Application("Keyboard Maestro Engine")
  command = kme.getvariable("command").split(".")
  start = new Date().getTime()
  kme.setvariable("command", {to:currentCommand+"."+start})
  if (currentCommand == command[0] & start-command[1]<kme.getvariable("FTTimeout")) {
  kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))
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
