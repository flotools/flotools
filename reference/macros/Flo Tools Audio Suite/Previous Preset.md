# Previous Preset

- Group: Flo Tools Audio Suite
- UID: 18D68121-4D3D-43DB-A50B-14495539D29F
- Enabled: True
- Triggers: [

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  window.buttons.byName("Previous Setting").click()
  value = window.popUpButtons.byName("Preset").value()
  vo.output(value)
  ```
