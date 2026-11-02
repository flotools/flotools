# Speak/Toggle Freeze Status

- Group: Flo Tools Inspector
- UID: DF394380-80A1-4B45-950F-8EFCB3C940A3
- Enabled: True
- Triggers: F

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
  button = track.buttons.whose({name:{_contains:"Frozen"}})[0]
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
  button = track.buttons.whose({name:{_contains:"Frozen"}})[0]
  value = ""+button.name()
  button.click()
  kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))
  while (true) {
  try {
  if (button.name() != value) break
  } catch (err) {
  }
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  delay(0.1)
  }
  value = button.name()
  vo.output(value)
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
