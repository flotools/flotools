# Speak/Choose Audio Suite Preset

- Group: Flo Tools Audio Suite
- UID: CEAA11A1-6E5F-4F6A-B630-A68B2BFC1346
- Enabled: True
- Triggers: Opt+Cmd+P

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "b"
  
  function single() {
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  value = window.popUpButtons.byName("Preset").value()
  vo.output(value)
  }
  
  function double() {
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  window.popUpButtons.byName("Preset").click()
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
