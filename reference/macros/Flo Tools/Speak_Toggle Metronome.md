# Speak/Toggle Metronome

- Group: Flo Tools
- UID: 21C5EE82-9392-4F65-A4CA-D7BA25601DEB
- Enabled: True
- Triggers: Opt+Keypad 7

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "on7"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("MIDI Control Cluster").buttons.byName("Metronome").value()
  if (value == "Selected") vo.output ("Metronome On")
  else vo.output("Metronome off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("MIDI Control Cluster").buttons.byName("Metronome")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Metronome On")
  else vo.output("Metronome off")
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
