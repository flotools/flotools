# Previous Fade In Shape Curve

- Group: Flo Tools Batch Fades
- UID: 456BB4D3-3257-4570-902A-B5148D91D46D
- Enabled: True
- Triggers: Shift+Left

## Actions

- SimulateKeystroke: Shift+Left
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("Fade In Shape").popUpButtons.byName("Fade In Shape").value()
  vo.output(shape+", Fade In Shape Curve.")
  ```
