# Preview Processing

- Group: Flo Tools Audio Suite
- UID: 79D8B668-39CE-4934-A135-B31F81EEE798
- Enabled: True
- Triggers: Ctrl+Opt+Shift+Cmd+P

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  try {
  window.buttons.byName("Preview Processing").click()
  } catch (err) {
  vo.output("Can't find Preview button!")
  }
  ```
