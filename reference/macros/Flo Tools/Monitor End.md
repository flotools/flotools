# Monitor End

- Group: Flo Tools
- UID: 2ED91EBB-3D9D-47A8-AB4A-58681E8CAC9B
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  function read(current) {
  if (current.indexOf("|")>-1) {
  mbt = current.split(/\| /)
  mbt[0] = "Bar "+mbt[0]+", "
  mbt[1] = "Beat "+mbt[1]+", "
  mbt[2] = mbt[2].replace(/^0+/, "")
  if (mbt[2] == 0) mbt[2] = ""
  else mbt[2] = "Tick "+mbt[2]
  msg = mbt[0]+mbt[1]+mbt[2]
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
  msg += ". End."
  vo.output(msg)
  }
  
  kme = Application("Keyboard Maestro Engine")
  c = kme.getvariable("FTEventIndex")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  last = ""
  try {
  last = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection End").value()
  } catch(err) {
  }
  read(last)
  while (kme.getvariable("FTEventIndex") == "5") {
  try {
  current = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection End").value()
  if (last != current) {
  last = current
  read(current)
  }
  } catch(err) {
  }
  delay(0.1)
  }
  ```
