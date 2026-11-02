# Speak/Choose Preset

- Group: Flo Tools Plugin
- UID: 800D2F46-7C27-4892-AA7C-6F90F0DC5EB0
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
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  value = window.popUpButtons.byName("Librarian menu").value()
  vo.output(value)
  }
  
  function double() {
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  window.popUpButtons.byName("Librarian menu").click()
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
