# Speak/Reset Peak Meter

- Group: Flo Tools Inspector
- UID: 1C6D9619-0269-4AB1-A64F-799FDEA688D5
- Enabled: True
- Triggers: P

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "p"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  tracks = mix.groups
  track = tracks.byName(vo.voCursor.textUnderCursor())
  slider = track.sliders["Peak"]
  meter = slider.attributes["AXValueDescription"].value()
  vo.output (meter)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  tracks = mix.groups
  track = tracks.byName(vo.voCursor.textUnderCursor())
  slider = track.sliders.byName("Peak")
  slider.click()
  delay(0.1)
  meter = slider.attributes["AXValueDescription"].value()
  vo.output (meter)
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
