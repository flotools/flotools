# Speak/Open Insert A

- Group: Flo Tools Inspector
- UID: F08671D6-BAA1-455E-8AE1-E9908063345A
- Enabled: True
- Triggers: 1

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "1"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  selector = track.groups["Inserts A-E"].buttons[0]
  assignment = track.groups["Inserts A-E"].buttons[5]
  slot = selector.name().replace("Insert selector", "")+". "+selector.value().replace("unassigned", "")
  assignment = assignment.value().replace("Insert Assignment ", "")
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
  track.groups["Inserts A-E"].buttons[5].click()
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
