# Speak Gain Reduction Meter, Toggle Gain Reduction Meter Monitor

- Group: Flo Tools Inspector
- UID: 34DF45E2-F217-4453-9563-210A0BDDF7BE
- Enabled: True
- Triggers: ;

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "\;"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  tracks = mix.groups
  track = tracks.byName(vo.voCursor.textUnderCursor())
  gainReduction = ""+track.buttons["Gain Reduction"].value()
  vo.output (gainReduction)
  }
  
  function double() {
  vo = Application("VoiceOver")
  kme = Application("Keyboard Maestro Engine")
  if (kme.getvariable("FTGRMonitor") == "1") {
  kme.setvariable("FTGRMonitor", {to:"0"})
  } else {
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  tracks = mix.groups
  kme.setvariable("FTGRMonitor", {to:"1"})
  vo.output("Watching Gain Reduction Meter")
  while (true) {
  try {
  name = vo.voCursor.textUnderCursor()
  track = tracks.byName(name)
  oldValue =  ""+track.buttons["Gain Reduction"].value()
  max = parseInt(oldValue.replace(" db", "").replace("minus ", "-"))
  kme.setvariable("FTGRMax", {to:""+max})
  while (true) {
  if (kme.getvariable("FTGRMonitor") != "1") {
  break;
  }
  if (name != vo.voCursor.textUnderCursor()) {
  name = vo.voCursor.textUnderCursor()
  track = tracks.byName(name)
  }
  currentValue = ""+track.buttons["Gain Reduction"].value()
  if (oldValue != currentValue) {
  oldValue = currentValue
  currentValue = parseInt(currentValue.replace(" db", "").replace("minus ", "-"))
  max = parseInt(kme.getvariable("FTGRMax"))
  if (currentValue<max) {
  kme.setvariable("FTGRMax", {to:""+currentValue})
  }
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  }
  
  }
  } catch(err) {
  }
  if (kme.getvariable("FTGRMonitor") != "1") {
  vo.output("Deactivate Gain Reduction monitor")
  break;
  }
  
  }
  }
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
