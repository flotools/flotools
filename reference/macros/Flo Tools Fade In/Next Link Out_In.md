# Next Link Out/In

- Group: Flo Tools Fade In
- UID: 5F66BB03-846C-494A-8DAB-0350BB484C64
- Enabled: True
- Triggers: Opt+Cmd+Down

## Actions

- SimulateKeystroke: Opt+Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Link Out / In").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Link Out/In.")
  ```
