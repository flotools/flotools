# Next Crossfade In Shape Curve

- Group: Flo Tools Batch Fades
- UID: FD840406-E744-441C-BE7C-01AD00774D85
- Enabled: True
- Triggers: Opt+Right

## Actions

- SimulateKeystroke: Opt+Right
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("In Shape").popUpButtons.byName("In Shape").value()
  vo.output(shape+", Crossfade In Shape Curve.")
  ```
