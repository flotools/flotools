# Render

- Group: Flo Tools Audio Suite
- UID: C26162A5-D033-4B70-A89C-DF7F7DA139E1
- Enabled: True
- Triggers: Ctrl+Opt+Shift+Cmd+R

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Audio Suite:"}})[0]
  try {
  window.buttons.byName("Render").click()
  vo.output("Render")
  } catch (err) {
  vo.output("Can't find render button!")
  }
  ```
