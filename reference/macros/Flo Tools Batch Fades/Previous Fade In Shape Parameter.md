# Previous Fade In Shape Parameter

- Group: Flo Tools Batch Fades
- UID: 348D1F52-5AA6-4210-AC19-CA6BEA9B0A87
- Enabled: True
- Triggers: Shift+Up

## Actions

- SimulateKeystroke: Shift+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Fade In Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Fade In Shape .")
  ```
