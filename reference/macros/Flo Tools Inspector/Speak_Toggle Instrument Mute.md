# Speak/Toggle Instrument Mute

- Group: Flo Tools Inspector
- UID: D614E7B9-1A9B-4A7A-9100-D57C38D7B45A
- Enabled: True
- Triggers: Opt+M

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "om"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  value = ""+track.groups.byName("Instrument").buttons.byName("MIDI Mute").value()
  if (value=="") value = "Off"
  else if (value=="on state") value = "On"
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups.byName("Instrument").buttons.byName("MIDI Mute").click()
  delay(0.1)
  value = track.groups.byName("Instrument").buttons.byName("MIDI Mute").value()
  if (value=="") value = "Off"
  else if (value=="on state") value = "On"
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
