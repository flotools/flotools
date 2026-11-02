# Next Crossfade In Shape Parameter

- Group: Flo Tools Crossfade
- UID: 92BC8EDB-B6A8-4586-A9F9-B53CCE08FA43
- Enabled: True
- Triggers: Opt+Down

## Actions

- SimulateKeystroke: Opt+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("In Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade In Shape.")
  ```
