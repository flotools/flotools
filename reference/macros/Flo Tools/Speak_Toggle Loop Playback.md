# Speak/Toggle Loop Playback

- Group: Flo Tools
- UID: 61820E5B-BB49-49C0-A1B1-5ACBF8F8D073
- Enabled: True
- Triggers: Shift+Cmd+L

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "csl"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  value = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Loop Playback").attributes["AXMenuItemMarkChar"].value()
  if (value == null) vo.output ("Loop Playback")
  else vo.output("Loop Playback , Checked")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  item = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Loop Playback")
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
