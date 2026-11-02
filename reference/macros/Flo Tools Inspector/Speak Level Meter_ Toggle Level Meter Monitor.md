# Speak Level Meter, Toggle Level Meter Monitor

- Group: Flo Tools Inspector
- UID: 252B218D-D108-456B-9DA4-683D3858BC80
- Enabled: True
- Triggers: L

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "l"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  tracks = mix.groups
  track = tracks.byName(vo.voCursor.textUnderCursor())
  roleDescription = ObjectSpecifier().roleDescription
  button = track.buttons.whose({_match:[roleDescription,"Level Meter"]})[0]
  meter = ""+button.value()
  if (meter == "") vo.output("No Signal")
  else vo.output (meter)
  }
  
  function double() {
  vo = Application("VoiceOver")
  if (kme.getvariable("FTLevelMonitor") == "1") {
  kme.setvariable("FTLevelMonitor", {to:"0"})
  } else {
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  tracks = mix.groups
  kme.setvariable("FTLevelMonitor", {to:"1"})
  vo.output("Watching level meter")
  roleDescription = ObjectSpecifier().roleDescription
  while (true) {
  try {
  name = vo.voCursor.textUnderCursor()
  track = tracks.byName(name)
  button = track.buttons.whose({_match:[roleDescription,"Level Meter"]})[0]
  oldValue = ""+button.value()
  while (true) {
  if (kme.getvariable("FTLevelMonitor") != "1") {
  break;
  }
  name = vo.voCursor.textUnderCursor()
  track = tracks.byName(name)
  button = track.buttons.whose({_match:[roleDescription,"Level Meter"]})[0]
  currentValue = ""+button.value()
  if (oldValue != currentValue) {
  if (currentValue=="") vo.output("No Level Meter")
  else vo.output(currentValue)
  oldValue = currentValue
  }
  delay(0.1)
  }
  } catch(err) {
  }
  if (kme.getvariable("FTLevelMonitor") != "1") {
  vo.output("Deactivate level monitor")
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
