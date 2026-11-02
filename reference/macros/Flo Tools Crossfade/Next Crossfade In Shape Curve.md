# Next Crossfade In Shape Curve

- Group: Flo Tools Crossfade
- UID: 3711FFBB-2395-4F41-A46B-0154CC2D456A
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
  vo.output(shape+", Crossffade, In.")
  ```
