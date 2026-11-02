# Speak/Toggle Wait for Note

- Group: Flo Tools
- UID: C833E106-1095-4829-86C7-903185E9176C
- Enabled: True
- Triggers: Opt+F11

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "of11"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("MIDI Control Cluster").buttons.byName("Wait for Note").value()
  if (value == "Selected") vo.output ("Wait for note On")
  else vo.output("Wait for note off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("MIDI Control Cluster").buttons.byName("Wait for Note")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Wait for note On")
  else vo.output("Wait for note off")
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
