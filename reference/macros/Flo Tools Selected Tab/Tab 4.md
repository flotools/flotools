# Tab 4

- Group: Flo Tools Selected Tab
- UID: 08CDB9D4-F8C7-483D-A806-FA5C622A04C7
- Enabled: True
- Triggers: Cmd+4

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
