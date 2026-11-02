# Speak/Toggle Quick Punch

- Group: Flo Tools
- UID: 228F3B92-0CB0-4459-88F4-976D58CC9011
- Enabled: True
- Triggers: Shift+Cmd+P

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "csp"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  value = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("QuickPunch").attributes["AXMenuItemMarkChar"].value()
  if (value == null) vo.output ("Quick Punch")
  else vo.output("Quick Punch, Checked")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  item = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("QuickPunch")
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
