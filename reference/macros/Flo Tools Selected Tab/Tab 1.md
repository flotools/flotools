# Tab 1

- Group: Flo Tools Selected Tab
- UID: 8ADB9D7E-7928-4685-9B03-951B883F29A4
- Enabled: True
- Triggers: Cmd+1

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
