# Speak/Toggle Conductor

- Group: Flo Tools
- UID: CB8785C0-960E-47C6-AE39-1847F3EF5C4E
- Enabled: True
- Triggers: Opt+F12

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "of12"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("MIDI Control Cluster").buttons.byName("Conductor Track").value()
  if (value == "Selected") vo.output ("Conductor On")
  else vo.output("Conductor off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("MIDI Control Cluster").buttons.byName("Conductor Track")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Conductor On")
  else vo.output("Conductor off")
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
