# Speak Shown Tracks, Show Track List Pop-up Menu

- Group: Flo Tools
- UID: 89B69BCD-1F27-453C-AF7C-A749EE5E389A
- Enabled: True
- Triggers: Opt+Shift+W

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "osw"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  shown = ObjectSpecifier().uiElements[0].buttons[0].name
  tracks = mix.tables.byName("Track List").rows.whose({_match:[shown,{_contains:"Shown"}]}).uiElements[1].buttons[0].name()
  msg = ""
  for (t in tracks) {
  msg += tracks[t].replace(/^Selected /,"")+". "
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  msg = msg.replace(/ track\. /g, ". ")
  if (msg=="") msg = "No tracks are currently shown."
  else msg = tracks.length+" Shown: "+msg
  vo.output (msg)
  }
  
  function double() {
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  button = mix.buttons.byName("Track List pop-up").click()
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
