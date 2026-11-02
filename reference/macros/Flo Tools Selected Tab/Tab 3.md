# Tab 3

- Group: Flo Tools Selected Tab
- UID: 1480A1D4-E82F-4F37-A2FC-C9A22E73BDB8
- Enabled: True
- Triggers: Cmd+3

## Actions

- SetVariableToText: command = '%ExecutingThisMacro%'
- ExecuteJavaScriptForAutomation
  ```javascript
  command = Application("Keyboard Maestro Engine").getvariable("command")
  command = parseInt(command.substring(command.length-1))
  window = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0].windows[0]
  obj = window.radioButtons[command-1]
  obj.click()
  Application("VoiceOver").output(obj.name()+" selected")
  ```
