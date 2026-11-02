# Next Fade Out Shape Curve

- Group: Flo Tools Batch Fades
- UID: 9A9C99B0-A7E3-452D-ABA1-CF719BBF1400
- Enabled: True
- Triggers: Cmd+Right

## Actions

- SimulateKeystroke: Cmd+Right
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("Fade Out Shape").popUpButtons.byName("Fade Out Shape").value()
  vo.output(shape+", Fade Out Shape Curve.")
  ```
