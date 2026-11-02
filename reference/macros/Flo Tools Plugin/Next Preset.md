# Next Preset

- Group: Flo Tools Plugin
- UID: C6FD72CC-0CBB-467D-BB95-7EE74CE69965
- Enabled: True
- Triggers: ]

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  window.buttons.byName("Next setting").click()
  value = window.popUpButtons.byName("Librarian menu").value()
  vo.output(value)
  ```
