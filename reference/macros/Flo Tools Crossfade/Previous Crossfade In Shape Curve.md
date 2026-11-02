# Previous Crossfade In Shape Curve

- Group: Flo Tools Crossfade
- UID: C708B32F-9E32-43C7-B310-BB80C7E77E92
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
  vo.output(shape+", Crossfade, In.")
  ```
