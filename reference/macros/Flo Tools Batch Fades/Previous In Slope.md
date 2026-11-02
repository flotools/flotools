# Previous In Slope

- Group: Flo Tools Batch Fades
- UID: 5A5EFB2E-6051-41EF-8521-56BAAC3828D2
- Enabled: True
- Triggers: Shift+Cmd+Up

## Actions

- SimulateKeystroke: Shift+Cmd+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Slope").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", In Slope .")
  ```
