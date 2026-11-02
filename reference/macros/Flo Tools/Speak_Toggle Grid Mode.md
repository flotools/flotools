# Speak/Toggle Grid Mode

- Group: Flo Tools
- UID: 82910228-592F-4BD4-A08B-A8A9CF779555
- Enabled: True
- Triggers: F4

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
  button = edit.groups.byName("Edit Mode Cluster").buttons.whose({name:{_contains:"Grid"}})
  value = button.value()
  name = ""+button.name()
  name = name.replace("Grid mode", "")
  if (value == "Selected") vo.output ("Grid mode, "+name)
  else vo.output("Grid mode, off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("Edit Mode Cluster").buttons.whose({name:{_contains:"Grid"}})[0]
  button.click()
  delay(0.1)
  value = button.value()
  name = ""+button.name()
  name = name.replace("Grid mode", "")
  if (value == "Selected") vo.output ("Grid mode, "+name)
  else vo.output("Grid mode, off")
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
