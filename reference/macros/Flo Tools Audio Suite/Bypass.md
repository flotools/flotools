# Bypass

- Group: Flo Tools Audio Suite
- UID: 71C6DD25-25C5-4B89-8C1F-6E9C82C4B487
- Enabled: True
- Triggers: Ctrl+Opt+Shift+Cmd+B

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  try {
  window.buttons.byName("Bypass").click()
  } catch (err) {
  vo.output("Can't find Bypass button!")
  }
  ```
