# Speak/Select Elastic Audio Plugin

- Group: Flo Tools Inspector
- UID: 613C6AFB-613B-4CCB-8EE0-7CFED22C14E3
- Enabled: True
- Triggers: E

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "e"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.uiElements.whose({name:{_contains:"Current Elastic Audio or ARA Plug-in"}})[0]
  value = ""+button.value()
  if (value == "") {
  value = "None"
  }
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.uiElements.whose({name:{_contains:"Elastic Audio or ARA Plug-in selector"}})[0].click()
  }
  
  kme = Application("Keyboard Maestro Engine")
  command = kme.getvariable("command").split(".")
  start = new Date().getTime()
  kme.setvariable("command", {to:currentCommand+"."+start})
  if (currentCommand == command[0] & start-command[1]<kme.getvariable("FTTimeout")) {
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
