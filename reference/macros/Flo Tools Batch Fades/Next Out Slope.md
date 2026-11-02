# Next Out Slope

- Group: Flo Tools Batch Fades
- UID: 5EBD25A4-EBAE-42ED-AC2D-93F1EE3B7228
- Enabled: True
- Triggers: Ctrl+Cmd+Down

## Actions

- SimulateKeystroke: Ctrl+Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Slope").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Out Slope .")
  ```
