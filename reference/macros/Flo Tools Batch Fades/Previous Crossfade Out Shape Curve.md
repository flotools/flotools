# Previous Crossfade Out Shape Curve

- Group: Flo Tools Batch Fades
- UID: 0834989E-3119-4CF5-8675-3D4125FC918F
- Enabled: True
- Triggers: Opt+Shift+Left

## Actions

- SimulateKeystroke: Opt+Shift+Left
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("Out Shape").popUpButtons.byName("Out Shape").value()
  vo.output(shape+", Crossfade Out Shape Curve.")
  ```
