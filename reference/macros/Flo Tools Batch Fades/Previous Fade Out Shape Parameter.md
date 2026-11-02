# Previous Fade Out Shape Parameter

- Group: Flo Tools Batch Fades
- UID: E8398D3F-1A17-44F1-A7CB-FF7F521A97E6
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
  obj = window.groups.byName("Fade Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Fade Out Shape .")
  ```
