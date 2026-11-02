# Monitor Length

- Group: Flo Tools
- UID: 3452EDAF-2EA5-4546-A6DF-69C56207EB3C
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  function read(current) {
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
  msg += ". length."
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
  last = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection Length").value()
  } catch(err) {
  }
  read(last)
  while (kme.getvariable("FTEventIndex") == "4") {
  try {
  current = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection Length").value()
  if (last != current) {
  last = current
  read(current)
  }
  } catch(err) {
  }
  delay(0.1)
  }
  ```
