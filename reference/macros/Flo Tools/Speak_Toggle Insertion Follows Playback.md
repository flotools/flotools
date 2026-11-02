# Speak/Toggle Insertion Follows Playback

- Group: Flo Tools
- UID: 20523AE1-876B-4B9A-893D-72F1AC744F78
- Enabled: True
- Triggers: Ctrl+N

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "Ctrln"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  value = edit.groups.byName("Cursor Tool Cluster").buttons.byName("Insertion Follows Playback").value()
  if (value == "Selected") vo.output ("Insertion Follows Playback, On")
  else vo.output("Insertion Follows Playback, Off")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  button = edit.groups.byName("Cursor Tool Cluster").buttons.byName("Insertion Follows Playback")
  button.click()
  delay(0.1)
  value = button.value()
  if (value == "Selected") vo.output ("Insertion Follows Playback, On")
  else vo.output("Insertion Follows Playback, Off")
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
