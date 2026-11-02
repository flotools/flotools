# Previous Link Out/In

- Group: Flo Tools Fade In
- UID: 2CA006EB-DE0E-44A7-85D6-744EB715FD8B
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
