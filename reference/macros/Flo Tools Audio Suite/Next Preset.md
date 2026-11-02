# Next Preset

- Group: Flo Tools Audio Suite
- UID: C8B042AA-40F4-43CC-A8A9-D0BA6CFB1EAF
- Enabled: True
- Triggers: ]

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  window.buttons.byName("Next Setting").click()
  value = window.popUpButtons.byName("Preset").value()
  vo.output(value)
  ```
