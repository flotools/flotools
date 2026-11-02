# Previous Crossfade Out Shape Parameter

- Group: Flo Tools Batch Fades
- UID: C0BD46D8-CB73-4DFD-9847-A4B68404DC98
- Enabled: True
- Triggers: Opt+Shift+Up

## Actions

- SimulateKeystroke: Opt+Shift+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade Out Shape .")
  ```
