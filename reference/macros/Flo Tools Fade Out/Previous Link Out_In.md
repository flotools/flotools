# Previous Link Out/In

- Group: Flo Tools Fade Out
- UID: FCD20C29-0233-456B-85D5-5CB9BAE573D9
- Enabled: True
- Triggers: Opt+Cmd+Up

## Actions

- SimulateKeystroke: Opt+Cmd+Up
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Link Out / In").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Link Out/In.")
  ```
