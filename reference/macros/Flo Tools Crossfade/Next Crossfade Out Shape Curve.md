# Next Crossfade Out Shape Curve

- Group: Flo Tools Crossfade
- UID: F6E24227-3232-4EEC-ACEC-965D9B9C0173
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
  shape = window.groups.byName("Out Shape").popUpButtons.byName("Out Shape").value()
  vo.output(shape+", Crossfade, Out.")
  ```
