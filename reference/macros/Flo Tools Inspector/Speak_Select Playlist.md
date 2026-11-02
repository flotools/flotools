# Speak/Select Playlist

- Group: Flo Tools Inspector
- UID: 366D9BB1-8DE8-4A77-BEF2-4C69C1878B03
- Enabled: True
- Triggers: \

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "sp"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  window = pt.windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.popUpButtons.whose({title:{_contains:"Track name"}})[0]
  value = button.name()
  value = value.replace("Track name", "")
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  window = pt.windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = window.groups.byName(vo.voCursor.textUnderCursor())
  button = track.popUpButtons.whose({title:{_contains:"Playlist Selector"}})[0]
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
