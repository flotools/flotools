# Speak/Toggle Midi Merge

- Group: Flo Tools
- UID: D97C6D65-2802-4541-81C8-14CBEEE2FAE6
- Enabled: True
- Triggers: Opt+Keypad 9

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "on9"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  merge = edit.groups.byName("MIDI Control Cluster").buttons.byName("MIDI Merge").value()
  if (merge == "Selected") vo.output ("Midi merge On")
  else vo.output("Midi merge off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("MIDI Control Cluster").buttons.byName("MIDI Merge")
  button.click()
  delay(0.1)
  merge = button.value()
  if (merge == "Selected") vo.output ("Midi merge On")
  else vo.output("Midi merge off")
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
