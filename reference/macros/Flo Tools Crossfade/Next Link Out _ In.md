# Next Link Out / In

- Group: Flo Tools Crossfade
- UID: 82B4E09F-0330-4030-979C-9CF9C89586D3
- Enabled: True
- Triggers: Down

## Actions

- SimulateKeystroke: Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Link Out / In").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Link Out/In.")
  ```
