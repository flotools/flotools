# Previous Crossfade In Shape Parameter

- Group: Flo Tools Crossfade
- UID: 1FA44547-5F78-45E4-8703-51DFCC118791
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
  vo.output(obj+", Crossfade In Shape.")
  ```
