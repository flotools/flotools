# Next Fade Out Shape Curve

- Group: Flo Tools Fade Out
- UID: 7C50FFBD-7E81-45A3-AF03-8F28A17D5AAD
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
  vo.output(shape+", Fade Out.")
  ```
