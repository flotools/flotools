# Previous Fade Out Shape Curve

- Group: Flo Tools Fade Out
- UID: B54D3D63-BECF-4D96-A354-2CE80E858AB3
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
  vo.output(shape+", Fade Out.")
  ```
