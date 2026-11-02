# Speak Record-Enabled Tracks, Disarm All Record-Enabled Tracks

- Group: Flo Tools
- UID: 7B187870-DC44-44BE-89C0-3A799F0885E5
- Enabled: True
- Triggers: Opt+Shift+R

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "osr"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  auxFilter = {name:{_contains:" - Aux Track"}}
  auxiliaryFilter = {name:{_contains:" - Auxiliary Track"}}
  armSpecifier = ObjectSpecifier().buttons["Track Record Enable"].value
  armFilter = {_match:[armSpecifier,""]}
  safeFilter = {_match:[armSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[armSpecifier,{_contains:"inactive"}]}
  folderFilter = {name:{_contains:"Folder Track"}}
  tracks = mix.groups.whose({_not:[folderFilter, auxFilter, auxiliaryFilter, masterFilter, armFilter, safeFilter, inactiveFilter]}).name()
  msg = ""
  for (t in tracks) {
  msg += tracks[t]+". "
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  msg = msg.replace(/ Track\. /g, ". ")
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  recordStatus = edit.groups.byName("Transport View Cluster").groups.byName("Normal Transport Buttons").buttons.whose({name:"Track Record Enabled"})
  if (msg=="" & recordStatus.length == 1) {
  msg = "Some tracks are armed."
  } else if (msg=="" & recordStatus.length == 0) {
  msg = "No tracks are armed."
  } else msg = tracks.length+" Armed: "+msg
  vo.output (msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  auxFilter = {name:{_contains:" - Aux Track"}}
  auxiliaryFilter = {name:{_contains:" - Auxiliary Track"}}
  armSpecifier = ObjectSpecifier().buttons["Track Record Enable"].value
  armFilter = {_match:[armSpecifier,""]}
  safeSpecifier = ObjectSpecifier().buttons["Track Record Enable"].value
  safeFilter = {_match:[safeSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[armSpecifier,{_contains:"inactive"}]}
  folderFilter = {name:{_contains:"Folder Track"}}
  recordStatus = edit.groups.byName("Transport View Cluster").groups.byName("Normal Transport Buttons").buttons.whose({name:"Track Record Enabled"})
  while (recordStatus.length == 1) {
  tracks = mix.groups.whose({_not:[auxFilter, auxiliaryFilter, masterFilter, folderFilter, armFilter, safeFilter, inactiveFilter]}).buttons["Track Record Enable"].click()
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  vo.output ("Disarmed all tracks.")
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
