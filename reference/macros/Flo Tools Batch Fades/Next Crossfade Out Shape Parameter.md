# Next Crossfade Out Shape Parameter

- Group: Flo Tools Batch Fades
- UID: 53007920-D2C6-490A-B84D-7E1D738E50BC
- Enabled: True
- Triggers: Opt+Shift+Down

## Actions

- SimulateKeystroke: Opt+Shift+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade Out Shape.")
  ```
