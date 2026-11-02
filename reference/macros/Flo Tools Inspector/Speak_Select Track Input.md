# Speak/Select Track Input

- Group: Flo Tools Inspector
- UID: 7A7404B4-51E6-4C3F-9ED0-36F38FF9277D
- Enabled: True
- Triggers: I

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "i"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  text = vo.voCursor.textUnderCursor()
  track = mix.groups.byName(text)
  if (text.indexOf(" - MIDI Track")>-1) {
  value = ""+track.buttons.whose({name:{_contains:"MIDI Input selector"}}).name()
  value = value.replace("MIDI Input selector", "")
  } else {
  value = ""+track.popUpButtons.whose({name:{_contains:"Input Path"}}).name()
  value = value.replace("Audio Input Path selector", "")
  }
  vo.output(value)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  text = vo.voCursor.textUnderCursor()
  track = mix.groups.byName(text)
  if (text.indexOf(" - MIDI Track")>-1) {
  track.buttons.whose({name:{_contains:"MIDI Input selector"}})[0].click()
  } else track.popUpButtons.whose({name:{_contains:"Input Path"}})[0].click()
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
