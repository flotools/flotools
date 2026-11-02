# Previous Out Slope

- Group: Flo Tools Batch Fades
- UID: BCD27252-0B06-4A87-BB17-A1DAAC5357C4
- Enabled: True
- Triggers: Ctrl+Cmd+Up

## Actions

- SimulateKeystroke: Ctrl+Cmd+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Slope").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Out Slope .")
  ```
