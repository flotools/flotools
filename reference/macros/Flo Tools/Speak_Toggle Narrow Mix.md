# Speak/Toggle Narrow Mix

- Group: Flo Tools
- UID: AF034F47-0C8E-402C-9B8F-A87F7F542079
- Enabled: True
- Triggers: Opt+Cmd+M

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  currentCommand = "cOM"
  
  function single() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  value = pt.menuBars[0].menuBarItems.byName("View").menus.byName("View").menuItems.byName("Narrow Mix").attributes["AXMenuItemMarkChar"].value()
  if (value == null) vo.output ("Narrow Mix")
  else vo.output("Narrow Mix, Checked")
  }
  
  function double() {
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  item = pt.menuBars[0].menuBarItems.byName("View").menus.byName("View").menuItems.byName("Narrow Mix")
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
