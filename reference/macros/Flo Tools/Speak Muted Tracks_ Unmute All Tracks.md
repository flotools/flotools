# Speak Muted Tracks, Unmute All Tracks

- Group: Flo Tools
- UID: BE81CE62-6368-4549-AD3F-38BCEB5DED1D
- Enabled: True
- Triggers: Opt+Shift+M

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "gm"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  muteSpecifier = ObjectSpecifier().buttons["Mute"].value
  muteFilter = {_match:[muteSpecifier,""]}
  soloFilter = {_match:[muteSpecifier,{_contains:"solo"}]}
  inactiveFilter = {_match:[muteSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, muteFilter, soloFilter, inactiveFilter]}).name()
  msg = ""
  for (t in tracks) {
  msg += tracks[t]+". "
  }
  msg = msg.replace(/ Track \. /g, ". ")
  if (msg=="") msg = "No tracks are muted."
  else msg = tracks.length+" Muted: "+msg
  vo.output(msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  muteSpecifier = ObjectSpecifier().buttons["Mute"].value
  muteFilter = {_match:[muteSpecifier,""]}
  soloFilter = {_match:[muteSpecifier,{_contains:"solo"}]}
  inactiveFilter = {_match:[muteSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, muteFilter, soloFilter, inactiveFilter]}).buttons["Mute"]()
  specifier = ObjectSpecifier().uiElements[1].buttons[0].name
  filter = {_match:[specifier,{_beginsWith:"Active "}]}
  activeGroups = mix.tables.byName("Group List").rows.whose(filter).uiElements[1].name()
  suspendGroup = false
  if (tracks.length > 0 & activeGroups.length > 0) {
  sys.keystroke("g", {using:["command down", "shift down"]})
  suspendGroup = true
  }
  for (t in tracks) {
  tracks[t].click()
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  if (suspendGroup) {
  sys.keystroke("g", {using:["command down", "shift down"]})
  }
  vo.output("unmuted all tracks.")
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
