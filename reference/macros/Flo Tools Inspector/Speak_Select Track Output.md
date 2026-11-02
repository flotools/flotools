# Speak/Select Track Output

- Group: Flo Tools Inspector
- UID: AC68B729-FACE-40B3-B44E-75D060D4E6F1
- Enabled: True
- Triggers: O

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "o"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  text = vo.voCursor.textUnderCursor()
  track = mix.groups.byName(text)
  if (text.indexOf(" - MIDI Track")>-1) {
  value = ""+track.buttons.whose({name:{_contains:"MIDI Output selector"}}).name()
  value = value.replace("MIDI Output selector", "")
  } else {
  value = ""+track.popUpButtons.whose({name:{_contains:"Output Path"}}).name()
  value = value.replace("Audio Output Path selector", "")
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
  button = track.buttons.whose({name:{_contains:"MIDI Output selector"}})[0]
  } else {
  button = track.popUpButtons.whose({name:{_contains:"Output Path"}})[0]
  }
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
