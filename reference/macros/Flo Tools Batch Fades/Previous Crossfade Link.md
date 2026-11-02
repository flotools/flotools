# Previous Crossfade Link

- Group: Flo Tools Batch Fades
- UID: 24FFACB2-3C41-4203-9F9B-3035B6C8FF5D
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
  obj = window.groups.byName("<<- Link ->>").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade Link.")
  ```
