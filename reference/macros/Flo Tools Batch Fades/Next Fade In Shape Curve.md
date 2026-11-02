# Next Fade In Shape Curve

- Group: Flo Tools Batch Fades
- UID: DD93F80A-1026-4B63-B44E-BAD89F2CB21C
- Enabled: True
- Triggers: Shift+Right

## Actions

- SimulateKeystroke: Shift+Right
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("Fade In Shape").popUpButtons.byName("Fade In Shape").value()
  vo.output(shape+", Fade In Shape Curve.")
  ```
