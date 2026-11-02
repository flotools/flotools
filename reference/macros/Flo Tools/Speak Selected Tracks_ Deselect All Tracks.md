# Speak Selected Tracks, Deselect All Tracks

- Group: Flo Tools
- UID: 2EB16086-C725-4C7A-A41D-6274C3EA26F5
- Enabled: True
- Triggers: Opt+Shift+L

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = ""
  
  function single() {
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  table = mix.tables.byName("Track List")
  tracks = table.rows.whose({selected:true}).uiElements[1].buttons[0].name()
  console.log(tracks)
  regex = /^Selected. (.*? - (\w+ )+)Track $/
  msg = ""
  tracks.forEach(track => {
  msg += regex.exec(track)[1]+". "
  })
  if (msg == "") msg = "No tracks are selected."
  else msg = tracks.length+" selected. "+msg
  Application("VoiceOver").output (msg)
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  if (window.buttons.byName("Track List Show/Hide").value().indexOf("Collapsed") !== -1) {
  window.buttons.byName("Track List Show/Hide").click()
  }
  window.tables.byName("Track List").rows.whose({selected:true}).uiElements[1].buttons[0].click()
  if (window.tables.byName("Track List").rows.whose({selected:true}).length == 0) {
  vo.output ("Deselected All Tracks.")
  } else {
  vo.output ("Please expand track list table.")
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
