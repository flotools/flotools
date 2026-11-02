# Previous Crossfade Out Shape Parameter

- Group: Flo Tools Crossfade
- UID: 0D658DC8-D474-4E0D-A791-C942F9C98752
- Enabled: True
- Triggers: Cmd+Up

## Actions

- SimulateKeystroke: Cmd+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade Out Shape.")
  ```
