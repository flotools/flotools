# Speak/Edit Nudge Value

- Group: Flo Tools
- UID: 347B48AC-0E8F-4631-90C1-D3AB3617AEDA
- Enabled: True
- Triggers: Cmd+F7

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "gs"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  msg = ""
  current = edit.groups.byName("Grid/Nudge Cluster").textFields.byName("Nudge Custom Value").value()
  if (current.indexOf("|")>-1) {
  mbt = current.split(/\| /)
  if (mbt[0] == 0) mbt[0] = ""
  else if (mbt[0] == 1) mbt[0] = mbt[0]+" bar, "
  else mbt[0] = mbt[0]+" bars, "
  if (mbt[1] == 0) mbt[1] = ""
  else if (mbt[1] == 1) mbt[1] = mbt[1]+" beat, "
  else mbt[1] = mbt[1]+" beats, "
  mbt[2] = mbt[2].replace(/^0+/, "")
  if (mbt[2] == 0) mbt[2] = ""
  else if (mbt[2] == 1) mbt[2] = mbt[2]+" tick"
  else mbt[2] = mbt[2]+" ticks"
  msg = mbt[0]+mbt[1]+mbt[2]
  if (msg == "") msg = "0 ticks"
  } else if (current.indexOf(".")>-1) {
  ms = current.split(/:/)
  ms[0] = ms[0].replace(/^0+/, "")
  if (ms[0]==0) ms[0] = ""
  else if (ms[0]==1) ms[0] = ms[0]+" minute"
  else ms[0] = ms[0]+"minutes"
  second = ms[1].split(/\./)
  second[0] = second[0].replace(/^0+/, "")
  if (second[0]==0) second[0] = ""
  else if (second[0]==1) second[0] = second[0]+" second"
  else second[0] = second[0]+" seconds"
  second[1] = second[1].replace(/^0+/, "")
  if (second[1]==0) second[1] = ""
  else if (second[1]==1) second[1] = second[1]+" millisecond"
  else second[1] = second[1]+" milliseconds"
  msg = ms[0]+second[0]+second[1]
  if (msg == "") msg = "0 seconds"
  } else msg = current
  msg += ". Nudge."
  vo.output (msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  counter = edit.groups.byName("Grid/Nudge Cluster").textFields.byName("Nudge Custom Value")
  value = counter.value()
  counter.click()
  if (value.includes(".")) {
  vo.output("Press Delete, then type Nudge value")
  } else {
  vo.output("Type nudge value.")
  }
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
