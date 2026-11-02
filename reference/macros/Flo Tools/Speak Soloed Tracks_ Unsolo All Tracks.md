# Speak Soloed Tracks, Unsolo All Tracks

- Group: Flo Tools
- UID: 2727205D-51F2-49D2-B1B0-66BA8D4D6F06
- Enabled: True
- Triggers: Opt+Shift+S

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "gs"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  soloSpecifier = ObjectSpecifier().buttons["Solo"].value
  soloFilter = {_match:[soloSpecifier,""]}
  safeFilter = {_match:[soloSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[soloSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, soloFilter, safeFilter, inactiveFilter]}).name()
  msg = ""
  for (track of tracks) {
  msg += track+". "
  }
  msg = msg.replace(/ Track \. /g, ". ")
  if (msg=="") msg = msg+"No tracks are soloed."
  else msg = tracks.length+" Soloed: "+msg
  vo.output(msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  soloSpecifier = ObjectSpecifier().buttons["Solo"].value
  soloFilter = {_match:[soloSpecifier,""]}
  safeFilter = {_match:[soloSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[soloSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, soloFilter, safeFilter, inactiveFilter]}).buttons["Solo"]()
  names = mix.groups.whose({_not:[masterFilter, soloFilter, safeFilter, inactiveFilter]}).name()
  specifier = ObjectSpecifier().uiElements[1].buttons[0].name
  filter = {_match:[specifier,{_beginsWith:"Active "}]}
  activeGroups = mix.tables.byName("Group List").rows.whose(filter).uiElements[1].name()
  suspendGroup = false
  if (tracks.length > 0 & activeGroups.length > 0) {
  sys.keystroke("g", {using:["command down", "shift down"]})
  suspendGroup = true
  }
  
  for (t in tracks) {
  if (!names[t].includes("Folder Track")) {
  tracks[t].click()
  }
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  
  for (t in tracks) {
  if (names[t].includes("Folder Track")) {
  tracks[t].click()
  }
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  
  if (suspendGroup) {
  sys.keystroke("g", {using:["command down", "shift down"]})
  }
  vo.output("unsoloed all tracks.")
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
