# Speak/Open Send E

- Group: Flo Tools Inspector
- UID: 1E895B5D-9C60-49DE-AF50-4A0CB186C7BD
- Enabled: True
- Triggers: Ctrl+5

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "5"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  selector = track.groups["Sends A-E"].buttons[8]
  assignment = track.groups["Sends A-E"].buttons[9]
  slot = selector.name().replace("Send selector", "")+". "+selector.value().replace("unassigned", "")
  assignment = assignment.value().replace("Send Assignment ", "")
  msg = slot+": "+assignment
  vo.output(msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends A-E"].buttons[9].click()
  kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))
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
