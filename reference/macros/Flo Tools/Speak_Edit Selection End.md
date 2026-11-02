# Speak/Edit Selection End

- Group: Flo Tools
- UID: BA15DD35-8B44-4294-BBB7-C8E49835ED91
- Enabled: True
- Triggers: Cmd+F2

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "cf2"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  msg = ""
  end = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection End").value()
  if (end.indexOf("|")>-1) {
  mbt = end.split(/\| /)
  mbt[0] = "Bar "+mbt[0]+", "
  mbt[1] = "Beat "+mbt[1]+", "
  mbt[2] = mbt[2].replace(/^0+/, "")
  if (mbt[2] == 0) mbt[2] = ""
  else mbt[2] = "Tick "+mbt[2]
  msg = mbt[0]+mbt[1]+mbt[2]
  }
  else if (end.indexOf(".")>-1) {
  ms = end.split(/:/)
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
  } else msg = end
  msg += ". end"
  vo.output (msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  counter = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection End")
  value = counter.value()
  counter.click()
  if (value.includes(".")) {
  vo.output("Press Delete, then type End value")
  } else {
  vo.output("Type end value")
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
