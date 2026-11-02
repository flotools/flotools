# Previous Link Out / In

- Group: Flo Tools Crossfade
- UID: A47F3FB3-EDB7-4C6C-9F52-BF573DDD95B9
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
  obj = window.groups.byName("Link Out / In").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Link Out/In.")
  ```
