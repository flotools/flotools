# Speak/Toggle Loop Record

- Group: Flo Tools
- UID: 17060DFD-4569-4033-92B1-5E3E5D8B22E7
- Enabled: True
- Triggers: Opt+L

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "ol"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  value = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Loop Record").attributes["AXMenuItemMarkChar"].value()
  if (value == null) vo.output ("Loop Record")
  else vo.output("Loop Record , Checked")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  item = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Loop Record")
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
