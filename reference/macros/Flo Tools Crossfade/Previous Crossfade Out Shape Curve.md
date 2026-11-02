# Previous Crossfade Out Shape Curve

- Group: Flo Tools Crossfade
- UID: B0A4EA1C-3FB3-4AA8-BC96-0938DC552357
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
  shape = window.groups.byName("Out Shape").popUpButtons.byName("Out Shape").value()
  vo.output(shape+", Crossfade, Out.")
  ```
