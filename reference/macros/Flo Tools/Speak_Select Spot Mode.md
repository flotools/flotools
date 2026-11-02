# Speak/Select Spot Mode

- Group: Flo Tools
- UID: D41A7D40-EC3F-490E-A38E-33563B9E6DF6
- Enabled: True
- Triggers: F3

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "f3"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("Edit Mode Cluster").buttons.byName("EditModeSpot").value()
  if (value == "Selected") vo.output ("Spot Mode, On")
  else vo.output("Spot Mode, Off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("Edit Mode Cluster").buttons.byName("EditModeSpot")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Spot Mode, On")
  else vo.output("Spot Mode, Off")
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
