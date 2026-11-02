# Speak/Toggle Bypass

- Group: Flo Tools Plugin
- UID: DAC44B3D-0948-4D6C-92FE-006AE0EB934C
- Enabled: True
- Triggers: Opt+B

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "b"
  
  function single() {
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  if (window.buttons.byName("Effect Bypass").value().indexOf("on") !== -1) value = "On"
  else value = "Off"
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  window.buttons.byName("Effect Bypass").click()
  delay(0.1)
  if (window.buttons.byName("Effect Bypass").value().indexOf("on") !== -1) value = "On"
  else value = "Off"
  vo.output(value)
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
