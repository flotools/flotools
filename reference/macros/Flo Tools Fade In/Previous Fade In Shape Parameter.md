# Previous Fade In Shape Parameter

- Group: Flo Tools Fade In
- UID: B764E305-995D-4089-926B-02D32AEB4DC9
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
  obj = window.groups.byName("In Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", In Shape .")
  ```
