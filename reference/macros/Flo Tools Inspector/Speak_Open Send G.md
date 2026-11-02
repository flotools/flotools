# Speak/Open Send G

- Group: Flo Tools Inspector
- UID: 5444DA62-4082-472A-B3B5-B104996A4346
- Enabled: True
- Triggers: Ctrl+7

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "7"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  selector = track.groups["Sends F-J"].buttons[2]
  assignment = track.groups["Sends F-J"].buttons[3]
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
  track.groups["Sends F-J"].buttons[3].click()
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
