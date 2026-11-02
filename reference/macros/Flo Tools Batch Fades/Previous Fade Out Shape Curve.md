# Previous Fade Out Shape Curve

- Group: Flo Tools Batch Fades
- UID: B4D8720E-149E-49DC-B948-027A541C777E
- Enabled: True
- Triggers: Cmd+Left

## Actions

- SimulateKeystroke: Cmd+Left
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("Fade Out Shape").popUpButtons.byName("Fade Out Shape").value()
  vo.output(shape+", Fade Out Shape Curve.")
  ```
