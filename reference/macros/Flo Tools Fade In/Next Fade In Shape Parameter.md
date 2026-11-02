# Next Fade In Shape Parameter

- Group: Flo Tools Fade In
- UID: 91510FDD-7E7A-4248-A8E6-1513BFE43F1A
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
  obj = window.groups.byName("In Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Fade In.")
  ```
