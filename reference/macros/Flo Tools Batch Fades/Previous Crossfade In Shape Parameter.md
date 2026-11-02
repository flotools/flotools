# Previous Crossfade In Shape Parameter

- Group: Flo Tools Batch Fades
- UID: 76AC612A-3F5C-4B43-A1E8-BB46E27A08CA
- Enabled: True
- Triggers: Opt+Up

## Actions

- SimulateKeystroke: Opt+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("In Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade In Shape .")
  ```
