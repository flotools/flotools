# Speak/Select Shuffle Mode

- Group: Flo Tools
- UID: A7B3EDA0-DC5C-410C-AAE2-C1A4DBA7A2AB
- Enabled: True
- Triggers: F1

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "f1"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("Edit Mode Cluster").buttons.byName("EditModeShuffle").value()
  if (value == "Selected") vo.output ("Shuffle Mode, On")
  else vo.output("Shuffle Mode, Off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("Edit Mode Cluster").buttons.byName("EditModeShuffle")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Shuffle Mode, On")
  else vo.output("Shuffle Mode, Off")
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
