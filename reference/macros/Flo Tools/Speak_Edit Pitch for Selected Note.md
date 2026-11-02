# Speak/Edit Pitch for Selected Note

- Group: Flo Tools
- UID: E5D2500D-0E04-494C-A049-94A51C5A6519
- Enabled: True
- Triggers: Opt+P

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "op"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  msg = edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Pitch").value()
  msg = msg.replace("x", "-DOUBLE Sharp")
  msg = msg.replace("#", "-Sharp ")
  msg = msg.replace("bb", "-DOUBLE Flat")
  msg = msg.replace("b", "-Flat ")
  msg += ". Pitch"
  vo.output (msg)
  console.log(msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  edit.groups.byName("Counter Display Cluster").textFields.byName("MIDI Note Pitch").click()
  vo.output("Type note pitch")
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
