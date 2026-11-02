# Speak Input Monitor-Enabled Tracks, Disable Input Monitor On All Tracks

- Group: Flo Tools
- UID: CF7CAA29-052E-4BEC-910F-757E788CCBC2
- Enabled: True
- Triggers: Opt+Shift+K

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "gk"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  inputFilter = {_match: [ ObjectSpecifier().buttons.name, { _contains: "Input monitoring enabled" } ]}
  audioFilter = { name: { _contains: " - Audio Track" } }
  tracks = mix.groups.whose({_and:[audioFilter, inputFilter]}).name()
  msg = ""
  try {
  for (t in tracks) {
  msg += tracks[t]+". "
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  } catch {
  }
  
  msg = msg.replace(/ Track\. /g, ". ")
  if (msg == "") msg = "No track has input monitor on"
  else msg = tracks.length+" Input on: "+msg
  vo.output(msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  inputFilter = {_match: [ ObjectSpecifier().buttons.name, { _contains: "Input monitoring enabled" } ]}
  audioFilter = {name:{_contains:" - Audio Track"}}
  try {
  tracks = mix.groups.whose({_and:[audioFilter, inputFilter]}).buttons["Input monitoring enabled"]()
  for (t in tracks) {
  tracks[t].click()
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  } catch {
  }
  msg = "Turned Off Input Monitor for all tracks"
  vo.output(msg)
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
