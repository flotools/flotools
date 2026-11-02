# Tab 2

- Group: Flo Tools Selected Tab
- UID: 656463B9-2F24-4E3C-B064-0EDD916AF0B6
- Enabled: True
- Triggers: Cmd+2

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
