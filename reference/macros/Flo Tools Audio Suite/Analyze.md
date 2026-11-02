# Analyze

- Group: Flo Tools Audio Suite
- UID: 1B41CD91-E8C7-4789-872D-A3C6AFDB5358
- Enabled: True
- Triggers: Ctrl+Opt+Shift+Cmd+N

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  try {
  window.buttons.byName("Analyze").click()
  vo.output("Analyze")
  } catch (err) {
  vo.output("Can't find analyze button!")
  }
  ```
