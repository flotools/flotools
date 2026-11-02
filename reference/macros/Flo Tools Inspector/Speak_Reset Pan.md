# Speak/Reset Pan

- Group: Flo Tools Inspector
- UID: B7196BF6-FE59-4DF8-AE2F-7603E8569D3B
- Enabled: True
- Triggers: N

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "n"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  pans = track.sliders.whose({name:{_contains:"Pan Knob"}})
  msg = ""
  for (p in pans) {
  value = ""+pans[p].attributes["AXValueDescription"].value()
  if (value=="") value = "No Pan"
  msg += value+". "
  }
  vo.output(msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  pans = track.sliders.whose({name:{_contains:"Pan Knob"}})
  msg = ""
  for (p in pans) {
  pans[p].click()
  delay(0.1)
  value = ""+pans[p].attributes["AXValueDescription"].value()
  msg += value+". "
  }
  vo.output(msg)
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
