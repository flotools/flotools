# Speak/Toggle Count In

- Group: Flo Tools
- UID: E9EE3AC3-1BE7-4336-AF97-6146BDFDFDEB
- Enabled: True
- Triggers: Opt+Keypad 8

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "on8"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  count = edit.groups.byName("MIDI Control Cluster").buttons.byName("Count in toggle").value()
  if (count == "Selected") vo.output ("Countin On")
  else vo.output("Countin off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("MIDI Control Cluster").buttons.byName("Count in toggle")
  button.click()
  delay(0.1)
  count = button.value()
  if (count == "Selected") vo.output ("Countin On")
  else vo.output("Countin off")
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
