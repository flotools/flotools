# Next crossfade Out Shape Parameter

- Group: Flo Tools Crossfade
- UID: 0890D22E-EDF7-4803-B20F-14E72720D89A
- Enabled: True
- Triggers: Cmd+Down

## Actions

- SimulateKeystroke: Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade Out Shape.")
  ```
