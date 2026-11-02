# Toggle Input Monitor

- Group: Flo Tools
- UID: 336D9616-EFBD-43D1-98C9-94A173E3D9EB
- Enabled: True
- Triggers: Opt+K

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  obj = pt.menuBars[0].menuBarItems.byName("Track").menus.byName("Track").menuItems.whose({name:{_contains:"Set Record Tracks to"}})[0]
  obj.click()
  delay(0.1)
  value = obj.name()
  if (obj.enabled() == false) {
  vo.output("Set Record Tracks to is Dimmed")
  } else {
  if (value.indexOf("Auto Input") > -1) vo.output("Input Only")
  else vo.output("Auto Input")
  }
  ```
