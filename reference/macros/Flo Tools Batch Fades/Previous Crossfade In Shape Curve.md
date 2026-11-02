# Previous Crossfade In Shape Curve

- Group: Flo Tools Batch Fades
- UID: 894B5278-E347-4E8A-9202-A8154FCF8CAC
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
  vo.output(shape+", Crossfade In Shape Curve.")
  ```
