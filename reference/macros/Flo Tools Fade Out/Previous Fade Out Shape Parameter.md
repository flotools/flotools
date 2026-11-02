# Previous Fade Out Shape Parameter

- Group: Flo Tools Fade Out
- UID: 421B1B80-21EE-4142-951E-750750EFEBDC
- Enabled: True
- Triggers: Up

## Actions

- SimulateKeystroke: Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Out Shape .")
  ```
