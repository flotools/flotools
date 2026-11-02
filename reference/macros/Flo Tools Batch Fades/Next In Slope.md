# Next In Slope

- Group: Flo Tools Batch Fades
- UID: 2BBCE161-2778-4445-A106-A781732D1637
- Enabled: True
- Triggers: Shift+Cmd+Down

## Actions

- SimulateKeystroke: Shift+Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Slope").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", In Slope .")
  ```
