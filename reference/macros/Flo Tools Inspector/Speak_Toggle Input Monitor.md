# Speak/Toggle Input Monitor

- Group: Flo Tools Inspector
- UID: 6B397B91-A570-47FD-91B7-807C30511E69
- Enabled: True
- Triggers: K

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "k"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  
  buttons = track.buttons.whose({name:{_contains:"Input monitoring"}})
  if (buttons.length>0) {
  value = buttons[0].name()
  } else {
  value = ""+track.buttons.byName("TrackInput Monitor").value()
  if (value=="") value = "Off"
  }
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  buttons = track.buttons.whose({name:{_contains:"Input monitoring"}})
  if (buttons.length > 0) {
  buttons[0].click()
  value = track.buttons.whose({name:{_contains:"Input monitor"}})[0].name()
  } else {
  track.buttons.byName("TrackInput Monitor").click()
  value = track.buttons.byName("TrackInput Monitor").value()
  if (value=="") value = "Off"
  }
  vo.output(value)
  }
  
  kme = Application("Keyboard Maestro Engine")
  command = kme.getvariable("command").split(".")
  start = new Date().getTime()
  kme.setvariable("command", {to:currentCommand+"."+start})
  if (currentCommand == command[0] & start-command[1]<kme.getvariable("FTTimeout")) {
  double()
  kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))
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
