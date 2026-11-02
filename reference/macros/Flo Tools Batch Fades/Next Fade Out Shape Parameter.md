# Next Fade Out Shape Parameter

- Group: Flo Tools Batch Fades
- UID: C789F858-DDF6-49AA-966A-E5BA0800BC5F
- Enabled: True
- Triggers: Cmd+Down

## Actions

- SimulateKeystroke: Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Fade Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Fade Out Shape..")
  ```
