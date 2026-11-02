# Previous Preset

- Group: Flo Tools Plugin
- UID: C2C7EACB-9C71-4961-8436-FA99062249CC
- Enabled: True
- Triggers: [

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  window.buttons.byName("Previous setting").click()
  value = window.popUpButtons.byName("Librarian menu").value()
  vo.output(value)
  ```
