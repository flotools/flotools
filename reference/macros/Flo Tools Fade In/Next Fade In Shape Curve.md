# Next Fade In Shape Curve

- Group: Flo Tools Fade In
- UID: D81E6BA6-605C-4C85-BCC8-5623589CBB97
- Enabled: True
- Triggers: Opt+Right

## Actions

- SimulateKeystroke: Opt+Right
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("In Shape").popUpButtons.byName("In Shape").value()
  vo.output(shape+", Fade In")
  ```
