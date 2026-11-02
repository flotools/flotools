# Next Fade In Shape Parameter

- Group: Flo Tools Batch Fades
- UID: F5E52450-3C8E-45BE-BE81-AD4DCC43EC49
- Enabled: True
- Triggers: Shift+Down

## Actions

- SimulateKeystroke: Shift+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Fade In Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Fade In Shape .")
  ```
