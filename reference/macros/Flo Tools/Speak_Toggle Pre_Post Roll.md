# Speak/Toggle Pre/Post Roll

- Group: Flo Tools
- UID: 2782DBF5-F0C6-4155-990E-07B7FFA106ED
- Enabled: True
- Triggers: Cmd+K

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "ck"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  value = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Pre/Post-Roll").attributes["AXMenuItemMarkChar"].value()
  if (value == null) vo.output ("Pre/Post Roll")
  else vo.output("Pre/Post Roll, Checked")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  item = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Pre/Post-Roll")
  item.click()
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
