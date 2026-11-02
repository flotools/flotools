# Track Options Menu

- Group: Flo Tools Inspector
- UID: 93C746D3-9062-423E-857F-E95F06F6E300
- Enabled: True
- Triggers: H

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "h"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.popUpButtons.whose({title:{_contains:"Track options"}})[0]
  value = button.name()
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.popUpButtons.whose({title:{_contains:"Track options"}})[0]
  button.click()
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
