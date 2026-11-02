# Previous Fade In Shape Curve

- Group: Flo Tools Fade In
- UID: B288A7C5-A16E-46DE-A3A6-D7DEF0B74112
- Enabled: True
- Triggers: Opt+Left

## Actions

- SimulateKeystroke: Opt+Left
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("In Shape").popUpButtons.byName("In Shape").value()
  vo.output(shape+", Fade In.")
  ```
